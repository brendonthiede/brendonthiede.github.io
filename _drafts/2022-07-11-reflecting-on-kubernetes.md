---
layout: post
title:  "Reflecting on Kubernetes: What I've Learned So Far"
date:   2022-07-12T00:02:14.162Z
categories: devops
externalImage: https://raw.githubusercontent.com/rancher/k3d/main/docs/static/img/k3d_logo_black_blue.svg
---
When I started actually using Kubernetes toward the middle of 2019, I'd been _aware_ of Kubernetes for quite a while, hearing many podcasts about what it did and the many tools to try and tame the beast that was swallowing all of tech, but I still didn't really know what to expect. Now over three years later I feel I've gotten the hang of it, but only through hitting some major speed bumps along the way.

## Many ways to install Kubernetes; all will have downsides

Immediately after accepting a job where I was going to be dealing with Kubernetes all the time, I decided I should probably learn about it, so I went through [Kelsey Hightower's Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way). Upon starting my new job I was introduced to Juju and the "Charmed Kubernetes" that Canonical provides, in order to install Kubernetes into an OpenStack environment. The former scenario you have full control over the binaries being installed and the system configuration, where as the latter is designed for simplicity and push button ease. The ease that the Charm was supposed to provide was blunted quite a bit by the operational requirements of my environment. Looking for alternative installation methods (Kubeadm, Kubespray, etc.) didn't turn up anything meeting our needs, in particular regarding compliance with the CIS Benchmark. In the end, my team resorted installing and configuring the binaries manually. The key reason that this worked for us was the fact that we had no need for modifying an existing cluster (upgrading, scaling out/in, replacing nodes, etc.) and instead, any maintenance would be done by replacing the entire cluster, which could be done in about 30 minutes. In place maintenance would have added a new level of complexity that may have made it worth figuring out how to harden one of the other installation methods.

## Not all Helm charts are created equal



One of the biggest frustrations I had in trying to use various tutorials - versions, assumed context

Cleaning up after you're done

Load balancing resources in different clouds

DNS Runs the world (or freezes it in place)

Certs are the root of the problem
