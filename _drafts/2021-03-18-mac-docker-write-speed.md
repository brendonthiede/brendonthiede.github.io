
[nonprd/test/blue] /appdev/openstack-ci$ time dd if=/dev/zero of=/appdev/speedtest bs=1024 count=100000
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 46.9982 s, 2.2 MB/s

real	0m47.005s
user	0m0.088s
sys	0m3.900s
[nonprd/test/blue] /appdev/openstack-ci$ time dd if=/dev/zero of=/tmp/speedtest bs=1024 count=100000
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 0.278643 s, 367 MB/s

real	0m0.281s
user	0m0.020s
sys	0m0.261s

[nonprd/test/blue] ~$ time dd if=/dev/zero of=/appdev/speedtest bs=1024 count=100000
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 22.9897 s, 4.5 MB/s

real	0m23.019s
user	0m0.062s
sys	0m3.670s
[nonprd/test/blue] ~$ ls -lh /tmp/speedtest
-rw-r--r-- 1 root root 98M Mar 18 09:47 /tmp/speedtest
[nonprd/test/blue] ~$ time bash -c "dd if=/dev/zero of=/tmp/speedtest bs=1024 count=100000 && mv /tmp/speedtest /appdev/speedtest"
100000+0 records in
100000+0 records out
102400000 bytes (102 MB, 98 MiB) copied, 0.280981 s, 364 MB/s

real	0m0.819s
user	0m0.014s
sys	0m0.395s
