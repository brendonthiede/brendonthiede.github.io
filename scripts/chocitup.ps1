# iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/brendonthiede/brendonthiede.github.io/master/scripts/chocitup.ps1'))

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Exit
}

$INSTALLED = (choco list)
$TOOLS = ""

if (-NOT (Get-Command npm -ErrorAction SilentlyContinue)) {
    $TOOLS += " nodejs"
}

# if npm roaming directory isn't in the path, add it
$NPM_ROAMING = (Split-Path -Path $(npm root -g) -Parent)
if (-NOT ($env:Path -like "*$NPM_ROAMING*")) {
    $env:Path += ";$NPM_ROAMING"
    # persist the path change to user environment variables
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::User)
}

if (-NOT (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
    $TOOLS += " googlechrome"
}

if (($INSTALLED | Select-String notepadplusplus).Length -eq 0) {
    $TOOLS += " notepadplusplus"
}

if (($INSTALLED | Select-String awscli).Length -eq 0) {
    $TOOLS += " awscli"
}

if (($INSTALLED | Select-String 7zip.install).Length -eq 0) {
    $TOOLS += " 7zip.install"
}

if (($INSTALLED | Select-String sql-server-management-studio).Length -eq 0) {
    $TOOLS += " sql-server-management-studio"
}

if ($TOOLS.Length -eq 0) {
    Write-Host "All chocolatey packages are already installed!"
}
else {
    $CHOCO_COMMAND = "choco install -y" + $TOOLS + " --ignore-checksums"

    Invoke-Expression $CHOCO_COMMAND
    Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
    refreshenv
}

if (-NOT (Get-Command rdcli -ErrorAction SilentlyContinue)) {
    npm install -g redis-cli
}

# Download https://raw.githubusercontent.com/brendonthiede/brendonthiede.github.io/master/scripts/Get-DbCreds.ps1 and add it to the path, then run it
Invoke-WebRequest -Uri https://raw.githubusercontent.com/brendonthiede/brendonthiede.github.io/master/scripts/Get-DbCreds.ps1 -OutFile Get-DbCreds.ps1

./Get-DbCreds.ps1
