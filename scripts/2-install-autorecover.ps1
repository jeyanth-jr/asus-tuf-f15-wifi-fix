# Run in an ADMIN PowerShell:  powershell -ExecutionPolicy Bypass -File .\scripts\2-install-autorecover.ps1
# Creates the scheduled task "MT7921 Wi-Fi auto-recover", which runs wifi-autorecover.ps1 as SYSTEM
# whenever the MediaTek driver logs event 5002 ("adapter is not functioning properly").
#
# The task runs as SYSTEM, so its script is copied into an admin-only folder first
# (%ProgramFiles%\MT7921-autorecover). Never point a SYSTEM task at a user-writable file.
# Remove with 2-uninstall-autorecover.ps1.
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not running as administrator. Right-click PowerShell > Run as administrator, then run this again.'
}
$source = Join-Path $PSScriptRoot 'wifi-autorecover.ps1'
if (-not (Test-Path $source)) { throw "Missing $source" }

$installDir = Join-Path $env:ProgramFiles 'MT7921-autorecover'
New-Item -ItemType Directory -Force $installDir | Out-Null
Copy-Item $source $installDir -Force
$script = Join-Path $installDir 'wifi-autorecover.ps1'

$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Rescan/restart the MediaTek MT7921 Wi-Fi card after a driver failure (mtkwlex 5002).</Description></RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='mtkwlex'] and EventID=5002]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$script"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
$tmp = Join-Path $env:TEMP 'mt7921-autorecover.xml'
$xml | Out-File $tmp -Encoding Unicode
schtasks /create /tn 'MT7921 Wi-Fi auto-recover' /xml $tmp /f
Remove-Item $tmp
'Installed. Recovery attempts are logged to ' + (Join-Path $installDir 'autorecover.log')
