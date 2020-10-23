# brendonthiede.github.io

## Overview

Jekyll blog using [Long Haul theme](http://github.com/brianmaierjr/long-haul)

## Setup

### Windows

Notes are at [2018-03-26-try-again.markdown](https://brendonthiede.github.io/devops/2018/03/27/try-again.html)

Scripted version if you use [Chocolatey](https://chocolatey.org/) (assumes Ruby 2.6 is still the current version):

```powershell
# As Admin:
cinst ruby -y
cinst msys2 -y
# To be safe, close the prompt and open a fresh admin PowerShell instalce to continue
C:\tools\ruby26\bin\gem install jekyll bundler
C:\tools\ruby26\bin\ridk install # choose the appropriate option, probably 3
```

```powershell
# From new shell in this directory:
bundle install
```

### Mac

If you have Homebrew installed:

```bash
brew install ruby
echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile

gem install jekyll bundler
```

### WSL2 w/ Ubuntu

This is not working...

```bash
sudo apt install ruby
gem install --user-install jekyll bundler
RUBY_USER_BIN=~/.gem/ruby/2.5.0/bin
echo "export PATH=${RUBY_USER_BIN}:\${PATH}" >>~/.profile
source ~/.profile
```

It complains about bundler not being available.

## Running Locally

```powershell
bundle install
bundle exec jekyll serve
```

## Upgrading Ruby Gems

In order to upgrade the Ruby Gems used by Jekyll, run the following:

```powershell
bundle update
```