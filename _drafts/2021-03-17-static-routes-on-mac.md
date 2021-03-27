---
layout: post
title:  "Managing Static Routes on Mac"
date:   2021-03-18T03:01:51.128Z
categories: devops
---

While connected to the VPN:

```bash
OKM-MAC-4XELVDQ:~ root# netstat -rn
Routing tables

Internet:
Destination        Gateway            Flags        Netif Expire
default            10.175.9.195       UGSc         utun2
default            192.168.1.1        UGScI          en0
10.175.9.195/32    127.0.0.1          UGSc           lo0
127                127.0.0.1          UCS            lo0
127.0.0.1          127.0.0.1          UH             lo0
169.254            link#6             UCS            en0      !
169.254.169.254    link#6             UHRLSW         en0      !
172.24.8.125       10.175.9.195       UGHS         utun2
172.24.176.125     10.175.9.195       UGHS         utun2
192.168.1          10.175.9.195       UGdCSc       utun2
192.168.1          link#6             UCSI           en0      !
192.168.1.1/32     10.175.9.195       UGdCSc       utun2
192.168.1.1        10:c:6b:e:39:45    UHLWIir        en0   1146
192.168.1.1/32     link#6             UCSI           en0      !
192.168.1.3        c8:3a:6b:9f:57:1c  UHLWI          en0    636
192.168.1.5        7c:d9:5c:57:79:e   UHLWIi         en0   1200
192.168.1.10       14:c1:4e:49:92:86  UHLWIi         en0   1196
192.168.1.111/32   10.175.9.195       UGdCSc       utun2
192.168.1.111/32   link#6             UCSI           en0      !
208.95.191.12      192.168.1.1        UGHS           en0
224.0.0/4          10.175.9.195       UGmdCSc      utun2
224.0.0/4          link#6             UmCSI          en0      !
224.0.0/4          link#18            UmCSI        utun2
224.0.0.251        link#18            UHmW3I       utun2     10
239.255.255.250    1:0:5e:7f:ff:fa    UHmLWI         en0
239.255.255.250    link#18            UHmW3I       utun2      6
255.255.255.255/32 link#18            UCS          utun2
255.255.255.255/32 link#6             UCSI           en0      !

Internet6:
Destination                             Gateway                         Flags         Netif Expire
default                                 fe80::%utun0                    UGcI          utun0
default                                 fe80::%utun1                    UGcI          utun1
::1                                     ::1                             UHL             lo0
fe80::%lo0/64                           fe80::1%lo0                     UcI             lo0
fe80::1%lo0                             link#1                          UHLI            lo0
fe80::%en5/64                           link#4                          UCI             en5
fe80::aede:48ff:fe00:1122%en5           ac:de:48:0:11:22                UHLI            lo0
fe80::aede:48ff:fe33:4455%en5           ac:de:48:33:44:55               UHLWIi          en5
fe80::%en0/64                           link#6                          UCI             en0
fe80::3e:1619:2e5f:1269%en0             a4:83:e7:c5:c4:b6               UHLI            lo0
fe80::%awdl0/64                         link#14                         UCI           awdl0
fe80::8c9d:48ff:fe69:9456%awdl0         8e:9d:48:69:94:56               UHLI            lo0
fe80::%llw0/64                          link#15                         UCI            llw0
fe80::8c9d:48ff:fe69:9456%llw0          8e:9d:48:69:94:56               UHLI            lo0
fe80::%utun0/64                         fe80::6cbe:c5f5:d7fa:e09b%utun0 UcI           utun0
fe80::6cbe:c5f5:d7fa:e09b%utun0         link#16                         UHLI            lo0
fe80::%utun1/64                         fe80::988:9d72:1264:ceea%utun1  UcI           utun1
fe80::988:9d72:1264:ceea%utun1          link#17                         UHLI            lo0
ff01::%lo0/32                           ::1                             UmCI            lo0
ff01::%en5/32                           link#4                          UmCI            en5
ff01::%en0/32                           link#6                          UmCI            en0
ff01::%awdl0/32                         link#14                         UmCI          awdl0
ff01::%llw0/32                          link#15                         UmCI           llw0
ff01::%utun0/32                         fe80::6cbe:c5f5:d7fa:e09b%utun0 UmCI          utun0
ff01::%utun1/32                         fe80::988:9d72:1264:ceea%utun1  UmCI          utun1
ff02::%lo0/32                           ::1                             UmCI            lo0
ff02::%en5/32                           link#4                          UmCI            en5
ff02::%en0/32                           link#6                          UmCI            en0
ff02::%awdl0/32                         link#14                         UmCI          awdl0
ff02::%llw0/32                          link#15                         UmCI           llw0
ff02::%utun0/32                         fe80::6cbe:c5f5:d7fa:e09b%utun0 UmCI          utun0
ff02::%utun1/32                         fe80::988:9d72:1264:ceea%utun1  UmCI          utun1
```

Just those routes related to 192.168.1.*:

```bash
OKM-MAC-4XELVDQ:~ root# netstat -rn | grep 192.168.1.
default            192.168.1.1        UGScI          en0
192.168.1          10.175.9.195       UGdCSc       utun2
192.168.1          link#6             UCSI           en0      !
192.168.1.1/32     10.175.9.195       UGdCSc       utun2
192.168.1.1        10:c:6b:e:39:45    UHLWIir        en0   1146
192.168.1.1/32     link#6             UCSI           en0      !
192.168.1.3        c8:3a:6b:9f:57:1c  UHLWI          en0    636
192.168.1.5        7c:d9:5c:57:79:e   UHLWIi         en0   1200
192.168.1.10       14:c1:4e:49:92:86  UHLWIi         en0   1196
192.168.1.111/32   10.175.9.195       UGdCSc       utun2
192.168.1.111/32   link#6             UCSI           en0      !
208.95.191.12      192.168.1.1        UGHS           en0
```

```bash
OKM-MAC-4XELVDQ:~ root# route get 192.168.1.96
   route to: synology
destination: 192.168.1.0
       mask: 255.255.255.0
    gateway: okm-dev-8whwwt2.ddmi.intra.renhsc.com
  interface: utun2
      flags: <UP,GATEWAY,DONE,CLONING,STATIC,PRCLONING>
 recvpipe  sendpipe  ssthresh  rtt,msec    rttvar  hopcount      mtu     expire
       0         0         0         0         0         0      1400         0
```

```bash
route add -net 191.168.1.0/24 -interface en0
```

```bash
route delete 192.168.1.1/32 -host 10.175.9.195 -interface utun2
route delete -host 192.168.1 -interface utun2
route delete 192.168.1/24 -interface utun2
```
