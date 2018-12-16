---
layout: post
title:  "Running Ansible on Windows"
date:   2018-12-11T19:22:28.807Z
categories: devops
---
I started using Ansible to manage the web server where my wife's site is hosted a few years ago, but at that time I had a Mac. Now I'm using Windows for my day to day. Ansible doesn't currently have a Windows installer, but thanks to the Windows Subsystem for Linux (WSL), you can use the same process as for Ubuntu (or a different distro, if that's what you set up).

If you haven't enabled WSL, there's an article here to walk you through that: [Windows Subsystem for Linux Installation Guide for Windows 10](https://docs.microsoft.com/en-us/windows/wsl/install-win10). I used the [manual distro download process](https://docs.microsoft.com/en-us/windows/wsl/install-manual) (since the Windows Store is disabled on my laptop) and installed Ubuntu.

All I had to do now to get Ansible installed was to open a "Bash on Ubuntu on Windows" shell and run the following:

```bash
sudo apt-get update
sudo apt-get install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible
```

In order to keep my code paths feeling the same on the Bash shell and PowerShell, I created a symlink on bash:

```bash
cd ~
ln -s /mnt/c/Users/$USER/Source/ Source
```

For getting my SSH keys set up I considered a symlink as well, but I realized file permissions would be messed up, so I opted to just copy and then adjust file permissions:

```bash
cp /mnt/c/Users/$USER/.ssh/* ~/.ssh/
chmod 600 ~/.ssh/*
```

All that was left was for me to set up my inventory file and vault password file, so I set those up real quick and then I ran my playbook. Success! After having some nightmarish thoughts of a Linux VM, booting from a live CD, or using an old (very old) other system, I was pleased that it was so easy to get things working on the system that I'm currently most comfortable with.