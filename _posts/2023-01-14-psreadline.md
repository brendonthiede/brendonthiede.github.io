---
layout: post
title:  "Better PowerShell with PSReadLine"
date:   2023-01-15T02:06:55.535Z
categories: devops
externalImage: https://upload.wikimedia.org/wikipedia/commons/a/af/PowerShell_Core_6.0_icon.png
---
If want an easy way to navigate your command history as you type in PowerShell, you may want to consider [PSReadLine](https://github.com/PowerShell/PSReadLine)

To update to the latest version of PSReadLine, close all instances of PowerShell, including in VS Code, etc., then open an Administrator instance of Command Prompt (not PowerShell) and run:

```cmd
pwsh -noprofile -command "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"
```

Then back in a PowerShell instance, you can configure PSReadLine by running:

```powershell
if ((Get-Content $PROFILE | Select-String "Import-Module PSReadLine").Length -eq 0) {
    Write-Output "Import-Module PSReadLine" | Add-Content "$PROFILE"
}
# Set-PSReadLineOption -PredictionSource HistoryAndPlugin
if ((Get-Content $PROFILE | Select-String "Set-PSReadLineOption -PredictionSource History").Length -eq 0) {
    Write-Output "Set-PSReadLineOption -PredictionSource History" | Add-Content "$PROFILE"
}
# Set-PSReadLineOption -PredictionViewStyle InlineView
if ((Get-Content $PROFILE | Select-String "Set-PSReadLineOption -PredictionViewStyle ListView").Length -eq 0) {
    Write-Output "Set-PSReadLineOption -PredictionViewStyle ListView" | Add-Content "$PROFILE"
}
if ((Get-Content $PROFILE | Select-String "Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete").Length -eq 0) {
    Write-Output "Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete" | Add-Content "$PROFILE"
}
if ((Get-Content $PROFILE | Select-String "Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward").Length -eq 0) {
    Write-Output "Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward" | Add-Content "$PROFILE"
}
if ((Get-Content $PROFILE | Select-String "Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward").Length -eq 0) {
    Write-Output "Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward" | Add-Content "$PROFILE"
}
```
