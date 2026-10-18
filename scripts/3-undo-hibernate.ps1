# Run in an ADMIN PowerShell: restores the power-plan values saved by 3-use-hibernate.ps1.
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not running as administrator. Right-click PowerShell > Run as administrator, then run this again.'
}
$backup = Join-Path $PSScriptRoot 'power-backup.json'
if (-not (Test-Path $backup)) { throw "No backup at $backup" }

foreach ($s in @(Get-Content $backup -Raw | ConvertFrom-Json)) {
    powercfg /setacvalueindex SCHEME_CURRENT $s.Sub $s.Setting $s.AC
    powercfg /setdcvalueindex SCHEME_CURRENT $s.Sub $s.Setting $s.DC
    "{0,-14} restored (AC {1}, DC {2})" -f $s.Setting, $s.AC, $s.DC
}
powercfg /setactive SCHEME_CURRENT
'Restored. Hibernate stays enabled; turn it off with "powercfg /hibernate off" if you want.'
