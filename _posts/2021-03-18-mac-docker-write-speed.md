---
layout: post
title:  "Docker Write Speeds on Mac"
date:   2021-03-18T17:19:16.084Z
categories: devops
image: hard-drive.png
---
I was noticing some slowness while using bind mounts in Docker on my Mac. Here are some observations that I made.

h2. Direct Bind Mount Interaction

```bash
$ time dd if=/dev/zero of=/shared-volume/speedtest bs=1024 count=100000
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 46.9982 s, 2.2 MB/s

real	0m47.005s
user	0m0.088s
sys	0m3.900s
```

h2. Writing to Docker File System

```bash
$ time dd if=/dev/zero of=/tmp/speedtest bs=1024 count=100000
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 0.278643 s, 367 MB/s

real	0m0.281s
user	0m0.020s
sys	0m0.261s
```

h2. Writing to Docker File System, then mv to Bind Mount

```bash
$ time bash -c "dd if=/dev/zero of=/tmp/speedtest bs=1024 count=100000 && mv /tmp/speedtest /shared-volume/speedtest"
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 0.280981 s, 364 MB/s

real	0m0.819s
user	0m0.014s
sys	0m0.395s
```

h2. Summary

After these observations I will start doing as much I/O heavy work outside of any bind mounts and then move any files that need to be available outside of the container to the bind mount after the fact.
