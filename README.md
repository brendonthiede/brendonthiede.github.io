# brendonthiede.github.io

## Overview

Jekyll blog using [Long Haul theme](http://github.com/brianmaierjr/long-haul)

## Setup

### Windows

Last tested on 2024-02-03 with Ruby 3.2.3, which required using `rbenv install 3.2.2-1` to install the correct version of Ruby after following the [rbenv for windows](https://github.com/ccmywish/rbenv-for-windows?tab=readme-ov-file#readme) installation steps.

Notes are at [2018-03-26-try-again.markdown](https://brendonthiede.github.io/devops/2018/03/27/try-again.html)

Scripted version if you use [Chocolatey](https://chocolatey.org/) (assumes Ruby 2.6 is still the current version):

```powershell
# As Admin:
cinst 7zip -y
cinst msys2 -y

# You should install rbenv using the instructions at https://github.com/ccmywish/rbenv-for-windows?tab=readme-ov-file#readme

# To be safe, close the prompt and open a fresh admin PowerShell instance to continue
rbenv install 3.2.2-1
ridk install # choose the appropriate option to install the development toolchain, probably 3, and then press enter again to exit after it's done
# change to this directory
rbenv local 3.2.2-1
gem install jekyll bundler
```

### Mac

If you have Homebrew installed:

```bash
brew install ruby
echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile

gem install jekyll bundler
```

## Running Locally

Start a new shell if are still in a shell where you ran any of the install/setup actions above, then run the following:

```powershell
bundle install
bundle exec jekyll serve
```

If there is an error along the lines of `cannot load such file -- webrick (LoadError)`, you can resolve the dependency with:

```bash
bundle add webrick
```

Then try running `bundle exec jekyll serve` again.

If there is an error mentioning `Error:  Too many open files - Failed to initialize inotify: the user limit on the total number of inotify instances has been reached.`, in Bash, you can fix this with:

```bash
echo 256 | sudo tee /proc/sys/fs/inotify/max_user_instances
```

Then try running `bundle exec jekyll serve` again.

## Upgrading Ruby Gems

In order to upgrade the Ruby Gems used by Jekyll, run the following:

```powershell
bundle update
```

## Reveal JS

Reveal JS is used to share presentations. To update the Reveal JS version, copy the contents of [https://github.com/hakimel/reveal.js/tree/master/dist](https://github.com/hakimel/reveal.js/tree/master/dist) into the `presentations\revealjs` folder.
