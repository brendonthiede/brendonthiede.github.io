---
layout: post
title:  "Puppeteer with Angular"
date:   2018-09-18 14:08:15 -0400
categories: devops
---
I have had many reasons for wanting to run tests in a headless configuration, and I also have reasons for not wanting to use Chrome on my personal machine (I don't even have it installed on my dev machine). In the past I have used PhantomJS, but ever since Chrome announced plans to allow the browser to operate in headless mode, development slowed down until recently the repository was [archived](https://github.com/ariya/phantomjs/issues/15344).

Later on I heard about [Puppeteer](https://github.com/GoogleChrome/puppeteer), which sounded like the best bet for picking up where PhantomJS left off. I tried it early on with some projects, but today I decided to use it with a base Angular sample application.  I thought I'd be able to search the web and find an easy tutorial for setting it up, but alas, the internet failed me.

Looking back at my old projects and trying out some simplifications, I came up with a very simple method for modifying the standard [Tour of Heroes](https://angular.io/tutorial) tutorial to use Puppeteer.

## Install Puppeteer

To add Puppeteer to your project you just need to run the following from your project root:

{% highlight bash %}
npm install --save-dev puppeteer
{% endhighlight %}

## Configure Karma to use Puppeteer

In order to have Karma use ChromeHeadless by default and to use the Chromium binary that gets installed with Puppeteer, you just need to modify the `karma.conf.js` file. The following needs to be added to the top of the file:

{% highlight javascript %}
process.env.CHROME_BIN = require('puppeteer').executablePath()
{% endhighlight %}

This will take care of the Chromium binary. Now to change the default browser for running tests. This is technically optional, as you can pass the `--browsers` argument to the command line, such as:

{% highlight bash %}
ng test --browsers=ChromeHeadless --watch=false
{% endhighlight %}

But one thing of note is that in order for me to get things running on Linux, I ended up using the `--no-sandbox` flag for ChromeHeadless. To make this easy, I added a custom launcher to the config named `ChromeHeadlessNoSandbox`, which is just `ChromeHeadless` with the `--no-sandbox` flag. Then I changed the setting for `browsers` to `['ChromeHeadlessNoSandbox']`

For me, making the changes to `karma.conf.js` ended up with the following:

{% highlight javascript %}
// Karma configuration file, see link for more information
// https://karma-runner.github.io/1.0/config/configuration-file.html

process.env.CHROME_BIN = require('puppeteer').executablePath()

module.exports = function (config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [
      require('karma-jasmine'),
      require('karma-chrome-launcher'),
      require('karma-jasmine-html-reporter'),
      require('karma-coverage-istanbul-reporter'),
      require('@angular-devkit/build-angular/plugins/karma')
    ],
    client: {
      clearContext: false // leave Jasmine Spec Runner output visible in browser
    },
    coverageIstanbulReporter: {
      dir: require('path').join(__dirname, '../coverage'),
      reports: ['html', 'lcovonly'],
      fixWebpackSourcePaths: true
    },
    reporters: ['progress', 'kjhtml'],
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: ['ChromeHeadlessNoSandbox'],
    customLaunchers: {
      ChromeHeadlessNoSandbox: {
        base: 'ChromeHeadless',
        flags: ['--no-sandbox']
      }
    },
    singleRun: false
  });
};
{% endhighlight %}

## Running Tests

With the changes made to the project, now running the tests as part of a CI pipeline are as easy as this:

{% highlight bash %}
npm install
ng test --watch=false
{% endhighlight %}

## Working with CentOS

To give the most possible flexibility, this solution needs to be able to run on Linux as well. My test box was CentOS 7 and I wanted to get Node 1.9 on it. In order to get the Angular CLI installed, I ran the following:

{% highlight bash %}
curl –silent –location https://rpm.nodesource.com/setup_9.x | sudo bash
sudo yum remove -y nodejs npm
sudo yum install -y nodejs
sudo yum install pango.x86_64 libXcomposite.x86_64 libXcursor.x86_64 \
  libXdamage.x86_64 libXext.x86_64 libXi.x86_64 libXtst.x86_64 \
  cups-libs.x86_64 libXScrnSaver.x86_64 libXrandr.x86_64 GConf2.x86_64 \
  alsa-lib.x86_64 atk.x86_64 gtk3.x86_64 ipa-gothic-fonts \
  xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-utils \
  xorg-x11-fonts-cyrillic xorg-x11-fonts-Type1 xorg-x11-fonts-misc -y
npm i -g @angular/cli
{% endhighlight %}

**Note:** The big list of dependencies that I installed were related to getting an error about `error while loading shared libraries: libx11.so.6: cannot open shared object file: no such file or directory` when Chromium tried to launch. I found an issue comment that pointed me in this direction here: https://github.com/GoogleChrome/puppeteer/issues/391#issuecomment-325420271

Taking it a bit further I started a dummy project and configured it for Puppeteer:

{% highlight bash %}
ng new puppeteer-test
cd puppeteer-test
npm i --save-dev puppeteer
CONF="src/karma.conf.js"
if [ $(cat src/karma.conf.js | grep '^process.env.CHROME_BIN' | wc -l) == 0 ]; then
  echo -e "process.env.CHROME_BIN = require('puppeteer').executablePath()\n$(cat ${CONF})" > ${CONF}
fi
if [ $(cat src/karma.conf.js | grep 'ChromeHeadlessNoSandbox' | wc -l) == 0 ]; then
  sed -i -e 's/browsers:.*\[.*\],/browsers: ['\''ChromeHeadlessNoSandbox'\''], customLaunchers: { ChromeHeadlessNoSandbox: { base: '\''ChromeHeadless'\'', flags: ['\''--no-sandbox'\''] } },/g' $CONF
fi
{% endhighlight %}

Now I can run the tests on Linux:

{% highlight bash %}
ng test --watch=false
{% endhighlight %}

## Protractor - Headless

I had originally forgotten to modify the `protractor.conf.js` file.  Here is what it takes to get protractor running via Puppeteer, with a default config that runs in headless mode.

Set `CHROME_BIN`:

```javascript
process.env.CHROME_BIN = require('puppeteer').executablePath();
```

And set `chromeOptions` to use `CHROME_BIN` and pass required args:

```javascript
  capabilities: {
    'browserName': 'chrome',
    chromeOptions: {
      binary: process.env.CHROME_BIN,
      args: ['--headless', '--disable-gpu', '--window-size=800,600', '--no-sandbox']
    }
  }
```

My final `protractor.conf.js` looked like this:

```javascript
// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts
process.env.CHROME_BIN = require('puppeteer').executablePath();
const { SpecReporter } = require('jasmine-spec-reporter');

exports.config = {
  allScriptsTimeout: 11000,
  specs: [
    './e2e/**/*.e2e-spec.ts'
  ],
  capabilities: {
    'browserName': 'chrome',
    chromeOptions: {
      binary: process.env.CHROME_BIN,
      args: ['--headless', '--disable-gpu', '--window-size=800,600', '--no-sandbox']
    }
  },
  directConnect: true,
  baseUrl: 'http://localhost:4200/',
  framework: 'jasmine',
  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000,
    print: function () { }
  },
  onPrepare () {
    require('ts-node').register({
      project: 'e2e/tsconfig.e2e.json'
    });
    jasmine.getEnv().addReporter(new SpecReporter({ spec: { displayStacktrace: true } }));
  }
};
```

## Protractor - with UI

There may come times that you want to watch the Protractor tests run. For that you just need to change the args for the `chromeOptions`, which I did by creating a derived "UI" config (`protractor.ui.conf.js`) that can be optionally specified as the config to use. Here is what the file looked like:

```javascript
var config = exports.config = require('./protractor.conf.js').config;

config.capabilities.chromeOptions.args = ['--window-size=800,600', '--no-sandbox'];
```

To use the optional config you can pass in the config parameter to `ng e2e`:

```powershell
ng e2e --protractor-config=./e2e/protractor.ui.conf.js
# or
npm run e2e -- --protractor-config=./e2e/protractor.ui.conf.js
```

## Conclusion

Using Puppeteer in your CI pipeline will make your builds more reliable, and it's very easy to setup. The only downside as I see it is that the Chromium binary will be downloaded by npm (a little over 100 Mb), which can slow things down a little bit, but I think in the long term it will save time in troubleshooting browser issues with cookies, extensions, etc., and the ability to easily leverage Linux is nice as well.