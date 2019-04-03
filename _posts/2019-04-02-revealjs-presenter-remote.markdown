---
layout: post
title:  "Presenter Mode for Reveal.js"
date:   2019-04-02T19:40:27Z
categories: devops
image: remote-control.svg
---
I love using Reveal.js. A few of the itches it scratches for me are that it allows me to use version control easily, it supports putting code in your slides, and it can be hosted on a webpage. If you want to see some of the presentations that I've written using Reveal.js, you can go to my [presentations page](/presentations).

There was, however, one thing that I really wanted to do, was to be able to display the presentation on one screen for the audience, but have a different view on my own screen, while still having the controls match up. I know I can do this using [slides.com](https://slides.com/), along with many other very cool things, but I wanted to keep things all running on my laptop. After some looking around I learned about the [Broadcast Channel API](https://developer.mozilla.org/en-US/docs/Web/API/Broadcast_Channel_API) that I can use from Chrome. The concept is quite simple: you create a channel and then either post to the channel or react to an `onmessage` event. I decided that what I was going to do was to create a presenter tab (just adding a query parameter to the URL of the existing slide deck) and have any "non-presenter" instances move to one slide prior to the slide of the presenter on the `slidechanged` event of the presenter. This turned out to be _very_ simple. I just added the following code to my presentation's javascript after `Reveal.initialize` was called:

```javascript
    Reveal.initialize({
      dependencies: [
        {
          src: 'plugin/highlight/highlight.js',
          async: true,
          callback: function () { hljs.initHighlightingOnLoad(); }
        }
      ],
      history: true
    });

    const controlChannel = new BroadcastChannel('controller');
    const urlParams = new URLSearchParams(window.location.search);
    const mode = urlParams.get('mode');

    if (mode === 'presenter') {
      Reveal.addEventListener('slidechanged', function (event) {
        controlChannel.postMessage({
          "presenterSlide": event.indexh
        });
      });
    } else {
      controlChannel.onmessage = function (ev) {
        Reveal.slide(ev.data.presenterSlide - 1);
      }
    }
```

A major assumption here is that you will only use horizontal slide progressions (I personally do this almost exclusively to make it easier to use a "clicker" device). Another flaw in this approach was that I couldn't show the last slide to the audience. I initially just added a dummy slide to the end so that the presenter would land on that and the audience would see the slide prior, however I didn't like that the progress indicator showed the audience that there was something else. In the end I decided to add a class of "presenter" to slides that should only be in the presenter's view and I just removed those from the DOM prior to calling Reveal.initialize. This resulted in the following code:

```javascript
    const controlChannel = new BroadcastChannel('controller');
    const urlParams = new URLSearchParams(window.location.search);
    const mode = urlParams.get('mode');

    if (mode !== 'presenter') {
      document.querySelectorAll('.presenter').forEach((elem) => { elem.parentNode.removeChild(elem); });
    }

    Reveal.initialize({
      dependencies: [
        {
          src: 'plugin/highlight/highlight.js',
          async: true,
          callback: function () { hljs.initHighlightingOnLoad(); }
        }
      ],
      history: true
    });

    if (mode === 'presenter') {
      Reveal.addEventListener('slidechanged', function (event) {
        controlChannel.postMessage({
          "presenterSlide": event.indexh
        });
      });
    } else {
      controlChannel.onmessage = function (ev) {
        Reveal.slide(ev.data.presenterSlide - 1);
      }
    }
```

Here's a sample of what it looks like in action, where the presenter view (bottom) is using the overview feature of Reveal.js:

![Usage Screenshot](/assets/img/revealjsremoteusage.jpg "Audience view on top, presenter view on the bottom")

If you want to try it out yourself you can open [this as the presenter tab](https://www.digestibledevops.com/presentations/2019-04-02-Lansing-DevOps-Meetup.html?mode=presenter#/) and in another tab open, [this as the audience view](https://www.digestibledevops.com/presentations/2019-04-02-Lansing-DevOps-Meetup.html#/). If you change the slide in the presenter tab you should see that the audience tab gets updated to be one prior.

To view the full source for how I use my presentations from Jekyll, you can look at my [GitHub repo](https://github.com/brendonthiede/brendonthiede.github.io).

## Edit

After just one use, I realized that I did not actually want to have the presenter to be a slide ahead. This actually greatly simplifies things. I technically got it working with just a very naive approach of just:

```javascript
    const controlChannel = new BroadcastChannel('controller');

    Reveal.initialize({
      dependencies: [
        {
          src: 'plugin/highlight/highlight.js',
          async: true,
          callback: function () { hljs.initHighlightingOnLoad(); }
        }
      ],
      history: true
    });

    Reveal.addEventListener('slidechanged', function (event) {
      controlChannel.postMessage({
        "indexh": event.indexh,
        "indexv": event.indexv
      });
    });
    controlChannel.onmessage = function (event) {
      Reveal.slide(event.data.indexh, event.data.indexv);
    }
```

Notice that this will allow for presentations that have vertical slides as well, so that's cool, but there is an extra event that happens where the audience view will also trigger a message post to the broadcast channel. Like I said, this technically worked, but I wanted to be a little smarter, so I added a kind of tracker to let me check where I had gone at the behest of a remote change. I also thought it would be good to allow changes to be synced both ways. Where I ended up was with this:

```javascript
    const controlChannel = new BroadcastChannel('controller');
    let remoteSlide = { indexh: -1, indexv: -1 };

    Reveal.initialize({
      dependencies: [
        {
          src: 'plugin/highlight/highlight.js',
          async: true,
          callback: function () { hljs.initHighlightingOnLoad(); }
        }
      ],
      history: true
    });

    Reveal.addEventListener('slidechanged', function (event) {
      if (remoteSlide.indexh !== event.indexh || remoteSlide.indexv !== event.indexv) {
        remoteSlide = { indexh: -1, indexv: -1 };
        controlChannel.postMessage({
          "indexh": event.indexh,
          "indexv": event.indexv
        });
      }
    });
    controlChannel.onmessage = function (event) {
      remoteSlide = event.data;
      Reveal.slide(event.data.indexh, event.data.indexv);
    }
```

A `remtoteSlide` value of `{ indexh: -1, indexv: -1 }` means "the last slide change was done in this tab", whereas any other value is checked against the current slide, and if they are the same values for `indexh` and `indexv`, the tab assumes it ended up there because a remote tab told it to change, otherwise, the tab again assumes it made the change, and therefore posts a message for any other tabs to change as well.