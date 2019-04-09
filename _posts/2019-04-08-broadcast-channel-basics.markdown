---
layout: post
title:  "Messing Around with Broadcast Channel API"
date:   2019-04-08T18:19:51Z
categories: devops
image: remote-control.svg
---
I had previously written about the Boradcast Channel API specifically in context of using it with Reveal.js, but some folks had asked me about Broadcast Channel more generically, so I create a [demo (click here to see it)](https://www.digestibledevops.com/broadcast-channel-iframe-demo/). [Source code is also available](https://github.com/brendonthiede/broadcast-channel-iframe-demo).

For this example, I chose to use multiple iframes in a single window, not because I think it's a good idea, but because it's easier to demonstrate.

## The Broadcast Channel API

Currently available in Chrome and Firefox, this API uses [Web Workers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API) behind the scenes, and can allow communication between different windows, tabs, frames, and iframes with the same origin, which are situations you might handled through AJAX requests in the past.

## Basic Usage

There are really only four things you can do with the Broadcast Channel API: create/join a channel, post a message, listen for messages, and leave a channel.

To join a broadcast channel, just call the constructor. All you need to know is the name of the channel (in this case, `crossFrameCommunication`), and then just call the constructor like this:

```javascript
const broadcastChannel = new BroadcastChannel('crossFrameCommunication');
```

From this point you can start posting and receiving messages.

To post a message, just call the `postMessage` method on the BroadcastChannel object and pass in any object (JSON, DOMString, etc.). Here's an example of passing in a JSON value:

```javascript
broadcastChannel.postMessage({
    user: 'brendon',
    product: 'banana',
    quantity: 8
});
```

To receive messages, add a listener for the `onmessage` event. When you respond to the event, the message will be in the `data` property of the event. Here a simple listener:

```javascript
broadcastChannel.onmessage = function (event) {
    console.log(`${event.data.user} wants to buy ${event.data.quantity} ${event.data.product}`);
};
```

Note that any messages posted by an instance (window, tab, frame, or iframe) will not trigger its own `onmessage` event.

## Things to Keep in Mind

First and foremost, this API only works with the same origin, so for different origins (different domain, a sub-domain, etc.), the Broadcast Channel API won't work.

The example I created is obviously very contrived, but I found it to be a simple way of showing the power of this API. That said, the way that I created this example has what are essentially four different web pages, three being loaded into a fourth, and as such, their resources are completely separate, meaning that, for example, the `main.css` is downloaded four times, since each page references it. If you want to have more control over shared resources, you should look into the [SharedWorker API](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker), where you can have a lot more control.

The reason I found this API in the first place was that I wanted to synchronize multiple windows of the same thing, in particular, a Reveal.js presentation, for which I found the Broadcast Channel API to be very effective. You can see a post I made about it here: [Presenter Mode for Reveal.js](https://www.digestibledevops.com/devops/2019/04/02/revealjs-presenter-remote.html)