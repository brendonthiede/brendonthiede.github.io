---
layout: post
title:  "Letting Claude drive Windows Chrome from WSL without the CDP timeouts"
date:   2026-07-16T12:00:00.000Z
categories: devops
---
I like to use the Playwright MCP with Claude in a lot of my workflows. Claude currently only runs in WSL, and WSLg struggles to show a Chrome window consistently on my machine, so interactive logins (SSO, OAuth) are unreliable if not impossible for me from inside WSL. The workaround I've found is to run Chrome on **Windows** and attach to it from WSL over the Chrome DevTools Protocol (CDP). This works great... until it randomly starts timing out. Here's the root cause and a self-healing fix. Full scripts: [brendonthiede/wsl-cdp-bridge](https://github.com/brendonthiede/wsl-cdp-bridge).

## The bridge

Chrome only exposes its debug port on loopback, which WSL2 (a separate network namespace) can't reach. A `netsh portproxy` listening on `0.0.0.0` bridges the gap:

```
WSL → <gateway>:9222 → [Windows netsh portproxy on 0.0.0.0] → Chrome loopback
```

```powershell
# launch Chrome with a dedicated (so it doesn't interfere with your personal profile)
chrome.exe --remote-debugging-port=9222 --remote-allow-origins=* `
  --user-data-dir=$env:LOCALAPPDATA\cdp-profile

# bridge 0.0.0.0:9222 to loopback, and open the firewall
netsh interface portproxy add v4tov6 listenaddress=0.0.0.0 listenport=9222 `
  connectaddress=::1 connectport=9222
New-NetFirewallRule -DisplayName "WSL CDP 9222" -Direction Inbound `
  -Action Allow -Protocol TCP -LocalPort 9222
```

From WSL, `curl http://<gateway>:9222/json/version` now reaches Chrome.

## Why it times out

The portproxy above forwards to `::1` (IPv6). But **Chrome binds its debug port to loopback with a nondeterministic address family**, so it's sometimes `127.0.0.1` (IPv4), and sometimes `[::1]` (IPv6). When Chrome lands on IPv4 and the portproxy forwards to IPv6, WSL's traffic goes to a dead port and hangs. Next launch it might line up again. That's the intermittency.

Fixing it means editing the portproxy with `netsh` in PowerShell, which needs to run as administrator. And the thing that notices the breakage is a non-elevated WSL script. So we need a way to run a specific elevated action from a non-elevated context.

## The fix: a pre-registered elevated task

Register a scheduled task **once** that runs with highest privileges. Because it's pre-registered, firing it later as a non-elevated WSL process will run it with the elevated privileges without even having to deal with a UAC prompt:

```powershell
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'AlignCdpPortproxy' -Principal $principal `
    -Action (New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument '-File C:\path\to\cdp-align-portproxy.ps1') -Force
```

```bash
# from WSL, non-elevated, no prompt:
schtasks.exe /run /tn AlignCdpPortproxy
```

The task's script reads which family Chrome is actually bound to and repoints the portproxy to match:

```powershell
if     ($listeners -match '\[::1\]:9222')  { $fam = 'v6' }  # -> connectaddress=::1
elseif ($listeners -match '127.0.0.1:9222'){ $fam = 'v4' }  # -> connectaddress=127.0.0.1
```

A WSL wrapper (`win-chrome.sh`) fires the task whenever the bridge is down and launches Chrome if it isn't running. No per-session admin; self-heals whichever address family Chrome picks.

## Two gotchas that make it actually reliable

**The portproxy listener can vanish.** After a `netsh delete`+`add`, the rule shows up in `netsh show all` but the `0.0.0.0:9222` socket sometimes isn't bound. The listener is owned by the IP Helper service. Restarting it rebinds every rule:

```powershell
Restart-Service iphlpsvc -Force
```

Only restart when the listener is actually missing, though, as a needless restart briefly tears down a working bridge.

**Don't read sockets with `Get-NetTCPConnection`.** It was inconsistently slow for me (~18s per call), enough to blow the task's time limit and leave it terminated mid-repoint. This had me chasing my tail a few times. Plain `netstat -ano` was consistently around 100ms, so using that instead kept things from timing out.

That's it. The scripts, setup steps, and a Superset query example are in the [repo](https://github.com/brendonthiede/wsl-cdp-bridge).
