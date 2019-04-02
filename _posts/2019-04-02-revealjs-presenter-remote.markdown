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
        { src: 'plugin/highlight/highlight.js', async: true, callback: function () { hljs.initHighlightingOnLoad(); } }
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
        { src: 'plugin/highlight/highlight.js', async: true, callback: function () { hljs.initHighlightingOnLoad(); } }
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

Here's a sample of what it looks like in action:

![Usage Screenshot](/assets/img/revealjsremoteusage.jpg "Usage screenshot")

If you want to try it out yourself you can open [this as the presenter tab](https://www.digestibledevops.com/presentations/2019-04-02-Lansing-DevOps-Meetup.html?mode=presenter#/) and in another tab open [this as the audience view](https://www.digestibledevops.com/presentations/2019-04-02-Lansing-DevOps-Meetup.html#/). If you change the slide in the presenter tab you should see that the audience tab gets updated to be one prior.

To view the full source for how I use my presentations from Jekyll, you can look at my [GitHub repo](https://github.com/brendonthiede/brendonthiede.github.io).