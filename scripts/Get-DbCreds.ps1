if (Test-Path -Path "C:\fv\*\*\DbUp") {
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

$DBServer
$DBUser
$DBPassword
$DBName
