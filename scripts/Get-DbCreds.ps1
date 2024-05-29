if (Test-Path -Path "C:\fv\*\*\Filevine.WindowsService.CalendarSyncService") {
    $DBConfig = "$((Get-ChildItem -Directory C:\fv\*\*\Filevine.WindowsService.CalendarSyncService\* | Sort-Object -Property CreationTime -Descending | Select-Object -First 1).FullName)\Filevine.WindowsService.CalendarSyncService.exe.config"
} elseif (Test-Path -Path "C:\fv\*\*\DbUp") {
    $DBConfig = "$((Get-ChildItem -Directory C:\fv\*\*\DbUp\* | Sort-Object -Property CreationTime -Descending | Select-Object -First 1).FullName)\FVDbUp.exe.config"
} else {
    $DBConfig = "$((Get-ChildItem -Directory C:\fv\*\*\Filevine.WindowsService.FilevineService\* | Sort-Object -Property CreationTime -Descending | Select-Object -First 1).FullName)\Filevine.Data.EF.dll.config"
}

[xml]$xml = Get-Content -Path $DBConfig

$ConnectionString = ($xml.SelectSingleNode("//configuration/connectionStrings/add[@name='FilevineContext']")).connectionString

$DBServer = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'data source=(.*)' -AllMatches).Matches[0].Groups[1].Value
$DBName = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'initial catalog=(.*)' -AllMatches).Matches[0].Groups[1].Value
$DBUser = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'user id=(.*)' -AllMatches).Matches[0].Groups[1].Value
$DBPassword = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'password=(.*)' -AllMatches).Matches[0].Groups[1].Value

# if the ImportService exists, grab the import DB creds from there
if (Test-Path -Path "C:\fv\*\*\Filevine.WindowsService.ImportService") {
# if the SqlServer module isn't installed, install it
    if (-NOT (Get-Module -ListAvailable -Name SqlServer)) {
        Install-Module -Name SqlServer -Force -AllowClobber
    }

    # query the filevine database for the import database ConnecionHost
    $SqlStatement = "SELECT TOP (1) ConnectionHost FROM [Filevine].[dbo].[ImportBatchConnection]"
    $ImportDBServer = (Invoke-Sqlcmd -ServerInstance $DBServer -Database $DBName -Query "$SqlStatement" -Username $DBUser -Password $DBPassword -TrustServerCertificate).ConnectionHost

    $ImportServiceConfig = "$((Get-ChildItem -Directory C:\fv\*\*\Filevine.WindowsService.ImportService\* | Sort-Object -Property CreationTime -Descending | Select-Object -First 1).FullName)\Filevine.WindowsService.ImportService.exe.config"

    [xml]$xml = Get-Content -Path $ImportServiceConfig

    $ConnectionString = ($xml.SelectSingleNode("//configuration/connectionStrings/add[@name='ImportContextMask']")).connectionString

    $ImportDBName = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'initial catalog=(.*)' -AllMatches).Matches[0].Groups[1].Value
    $ImportDBUser = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'user id=(.*)' -AllMatches).Matches[0].Groups[1].Value
    $ImportDBPassword = ($ConnectionString -replace ';', "`n" | Select-String -Pattern 'password=(.*)' -AllMatches).Matches[0].Groups[1].Value

    Write-Host "`nImport Database Credentials:"
    $ImportDBServer
    $ImportDBUser
    $ImportDBPassword

    Write-Host "`nImport Database Name:"
    $ImportDBName
}

Write-Host "`nFilevine Database Credentials:"

$DBServer
$DBUser
$DBPassword

Write-Host "`nFilevine Database Name:"
$DBName
