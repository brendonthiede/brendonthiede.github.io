---
layout: post
title:  "Where do spans come from? A Sentry and Scala love story."
date:   2026-08-05T12:00:00.000Z
categories: devops
---
When the JVM loves an observability platform very much... look, it's complicated. There is a third party involved (nothing wrong with some couple's counseling), and it is doing most of the work.

On paper this relationship has no business working. The Sentry Java SDK keeps your request context in a `ThreadLocal`. A Scala app changes threads every time you look at it. Tracing should fall apart the first time a `Future` hops threads, and it doesn't. Here's what's going on. Sentry's Java SDK is on GitHub, so we can go straight to the source.

## The model that says it can't work

Sentry's Java SDK keeps a *scope*: the bag of tags, user, breadcrumbs and active span that get stamped onto an event. Fork a scope, set some tags, log an error, and the error carries the tags.

The catch is where that scope lives. `io.sentry.DefaultScopesStorage` holds it in a `private static ThreadLocal<IScopes>`. In a Scala app that is a death sentence for context. Every `map`, every `flatMap`, every `Future` continuation can land on a different thread out of the pool. By the time your database call fails, you're several threads away from the one that started the request, and a thread-local is empty.

So: no span, no transaction, an orphan error. Except in production I get errors attached to the right request, and route-templated transaction names like `GET /organizations/*/facilities/*/people/*`. Something is clearly propagating.

## The third party: the storage gets swapped

With the OpenTelemetry javaagent attached, the SDK is not using that thread-local at all. `io.sentry.ScopesStorageFactory` decides at startup:

```java
if (Platform.isJvm()
    && loadClass.isClassAvailable("io.sentry.opentelemetry.OtelContextScopesStorage", logger)) {
  // reflectively instantiate it, use it as the IScopesStorage
}
// else fall back to DefaultScopesStorage (the ThreadLocal)
```

That class ships **inside the agent jar**. Attach `-javaagent:sentry-opentelemetry-agent.jar` and the branch is taken. Skip the agent, and you get the thread-local. Same application code, two completely different propagation stories, and nothing in your code tells you which one you're running.

What the OTel version does is short:

```java
// OtelContextScopesStorage
set(scopes) -> Context.current().with(SENTRY_SCOPES_KEY, scopes).makeCurrent()
get()       -> Context.current().get(SENTRY_SCOPES_KEY)
```

Sentry scopes now live inside the OpenTelemetry `Context`. That single move is what makes everything else work, because OTel `Context` is a solved problem: it's immutable, and the agent instruments the things that move it between threads.

## Spans and scopes are forked by the same operation

The second half of the puzzle is how a span gets *into* that scope in the first place, given that no application code calls a Sentry tracing API.

The agent registers its own OTel `ContextStorage` through the SPI. Every context that gets attached is wrapped in a `SentryContextWrapper`, and the wrapper's `with` method is where the magic sits:

```java
// SentryContextWrapper.with(key, value)
result = delegate.with(key, value);
if (isOpentelemetrySpan(key)) {          // is this the OTel "span" key?
  result = forkCurrentScope(result);     // then fork a Sentry scope too
}
```

`forkCurrentScope` looks the span up in `SentryWeakSpanStorage`, forks the current Sentry scopes, and calls `scopes.setActiveSpan(span)`. In other words: **making a span current and forking a Sentry scope are the same operation.** You never opt in. Any instrumentation that starts a span (HTTP server, JDBC, HTTP client) has also handed you a fresh Sentry scope bound to it.

Then at capture time, `SentryClient.applyScope` closes the loop:

```java
if (event.getContexts().getTrace() == null) {
  final ISpan span = scope.getSpan();
  if (span != null) {
    event.getContexts().setTrace(span.getSpanContext());          // real span
  } else {
    event.getContexts().setTrace(
      TransactionContext.fromPropagationContext(scope.getPropagationContext()));  // fallback
  }
}
```

That's the whole of "span recognition". Your logging call reaches a logback appender, the appender calls `Sentry.captureEvent`, and the trace and span IDs come off whatever scope the context is holding.

## Why the thread hops don't lose it

None of that propagation is the application's doing. The agent ships OTel instrumentation modules for `executors`, `scala-forkjoin-2.8`, `akkaactor` and `pekkoactor`, `akkahttp` and `pekkohttp`, `netty`, `playmvc`, `playws`, `reactornetty` and `rediscala`. When you submit work to an instrumented executor, it captures `Context.current()` at submit time and re-attaches it on the worker thread before your code runs.

`Context` being immutable is the load-bearing part. The task doesn't hold a reference to something mutable that might get popped out from under it; it holds a snapshot that still contains the scope. So a `Future` chain started inside a scope keeps the tags, even though the scope was popped on the calling thread long before the continuation ran.

## The part that bit us

We had a helper that forked a scope, tagged it, and ran a block, with a comment that read roughly:

> `block` runs on the calling thread and must stay synchronous: the forked scope is thread-local, so async work started inside it would be tagged with nothing.

Half right, in the worst way. Run it without the agent, in local dev or in the unit tests, and the comment is exactly correct. Run it in production with the agent attached and it's backwards: the async work *is* tagged, because the context it captured still holds the forked scope.

The rule ("keep the block synchronous") survives. The reason doesn't, and the reason is what someone will use two years from now to decide whether their change is safe. The honest version is that the two configurations disagree about propagation, and only synchronous use behaves the same in both.

Worth internalizing generally: **your tests do not exercise your production tracing.** Unit tests almost never run with the javaagent, so every scope assertion you write is an assertion about `DefaultScopesStorage`, not about the thing that runs in prod.

## Three things that are easy to trip over

**The agent jar contains a whole copy of the SDK.** A `-javaagent` jar is appended to the system class path, so `io.sentry.*` resolves from the agent, not from the version your build tool resolved. That's why the agent version and the `sentry-logback` version in your build have to be pinned together. Mismatch them and `Sentry.init` throws at startup.

**`Scope.activeSpan` is a `WeakReference<ISpan>`.** If the span wrapper has been collected by the time an event is captured, `getSpan()` returns null and the event quietly falls back to propagation-context linking. The error still has a trace ID, so it still looks fine. It's just attached to less than you think.

**A sample rate of 1.0 will find every gap in your naming.** Turning tracing on across our backend, the single largest bucket of transactions was `<unlabeled transaction>`, over a million events a day, comfortably ahead of any real route. Those are spans from entry points the HTTP instrumentation doesn't name: workers, scheduled jobs, anything that isn't a Play request. They cost exactly the same as the useful ones.

## If you want to confirm it in your own build

Don't take my word for the wiring. Two cheap checks tell you which of the two worlds you're in:

- Log `Sentry.class.getProtectionDomain().getCodeSource().getLocation()` at boot. If it points at the agent jar rather than your dependency cache, the agent's copy won.
- Set a tag inside a forked scope, start a `Future` inside that same block, and log an error from the continuation. If the tag is on the event, context is propagating. If it isn't, you're on the thread-local and every assumption above flips.

The relationship works fine. It just isn't the two of them doing the work.
