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
default            192.168.1.1        UGSc           en0
127                127.0.0.1          UCS            lo0
127.0.0.1          127.0.0.1          UH             lo0
169.254            link#6             UCS            en0      !
169.254.169.254    link#6             UHRLSW         en0      !
192.168.1          link#6             UCS            en0      !
192.168.1.1/32     link#6             UCS            en0      !
192.168.1.1        10:c:6b:e:39:45    UHLWIir        en0   1187
192.168.1.5        7c:d9:5c:57:79:e   UHLWIi         en0   1193
192.168.1.10       14:c1:4e:49:92:86  UHLWIi         en0   1188
192.168.1.111/32   link#6             UCS            en0      !
192.168.1.255      ff:ff:ff:ff:ff:ff  UHLWbI         en0      !
224.0.0/4          link#6             UmCS           en0      !
239.255.255.250    1:0:5e:7f:ff:fa    UHmLWI         en0
255.255.255.255/32 link#6             UCS            en0      !

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
default            192.168.1.1        UGSc           en0
192.168.1          link#6             UCS            en0      !
192.168.1.1/32     link#6             UCS            en0      !
192.168.1.1        10:c:6b:e:39:45    UHLWIir        en0   1197
192.168.1.5        7c:d9:5c:57:79:e   UHLWIi         en0   1087
192.168.1.10       14:c1:4e:49:92:86  UHLWIi         en0   1186
192.168.1.111/32   link#6             UCS            en0      !
```

```bash
OKM-MAC-4XELVDQ:~ root# route get 192.168.1.96
   route to: synology
destination: synology
  interface: en0
      flags: <UP,HOST,DONE,LLINFO,WASCLONED,IFSCOPE,IFREF>
 recvpipe  sendpipe  ssthresh  rtt,msec    rttvar  hopcount      mtu     expire
       0         0         0        23        27         0      1500       923
```
