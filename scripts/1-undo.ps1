# Run in an ADMIN PowerShell: restores the MT7921 driver settings saved by 1-disable-mt7921-lowpower.ps1.
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not running as administrator. Right-click PowerShell > Run as administrator, then run this again.'
}
$backup = Join-Path $PSScriptRoot 'mt7921-backup.reg'
if (-not (Test-Path $backup)) { throw "No backup at $backup" }

# reg import only adds/overwrites, so remove the values the tweak created that were absent before.
$classRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
$key = Get-ChildItem $classRoot | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).MatchingDeviceId -like 'PCI\VEN_14C3&DEV_7961*' } | Select-Object -First 1
$saved = Get-Content $backup -Raw
foreach ($name in 'LowPowerEnable', 'DeInitLP', 'L1SSModeLevel', 'PsEnable') {
    if ($saved -notmatch "`"$name`"=") { Remove-ItemProperty $key.PSPath -Name $name -ErrorAction SilentlyContinue }
}
reg import $backup
'Restored. Shut down and power on (or restart the Wi-Fi device) to apply.'
