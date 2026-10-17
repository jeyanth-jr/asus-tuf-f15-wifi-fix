# Run in an ADMIN PowerShell:  powershell -ExecutionPolicy Bypass -File .\scripts\1-disable-mt7921-lowpower.ps1
# Turns off the MT7921 driver's hidden low-power features (firmware deep sleep and PCIe L1 substates).
# Backs up the driver's registry key first; undo with 1-undo.ps1.
#
# Value names come from the registry-name table inside mtkwl6ex.sys (3.0.1.1314).
# Their exact semantics are inferred from names, not decompiled: test, then keep or undo.

$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not running as administrator. Right-click PowerShell > Run as administrator, then run this again.'
}
$classRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
$key = Get-ChildItem $classRoot -ErrorAction SilentlyContinue |
    Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).MatchingDeviceId -like 'PCI\VEN_14C3&DEV_7961*' } |
    Select-Object -First 1
if (-not $key) { throw 'MT7921 driver key not found. Is the MediaTek driver installed?' }

$backup = Join-Path $PSScriptRoot 'mt7921-backup.reg'
if (-not (Test-Path $backup)) {
    reg export ($key.Name) $backup /y | Out-Null
    "Backup written: $backup"
} else { "Backup already exists, keeping original: $backup" }

$settings = [ordered]@{
    LowPowerEnable = '0'   # firmware low-power / deep-sleep handoff (INF default 1)
    DeInitLP       = '0'   # low-power on de-init (INF default 1)
    L1SSModeLevel  = '0'   # PCIe L1 substates level (absent = driver default)
    PsEnable       = '0'   # driver power save (absent = driver default)
}
foreach ($name in $settings.Keys) {
    $old = (Get-ItemProperty $key.PSPath -Name $name -ErrorAction SilentlyContinue).$name
    Set-ItemProperty -Path $key.PSPath -Name $name -Value $settings[$name] -Type String
    "{0,-16} {1} -> {2}" -f $name, ($(if ($null -eq $old) { '(unset)' } else { $old })), $settings[$name]
}

'Rescanning hardware and restarting the Wi-Fi device so the driver re-reads its settings...'
pnputil /scan-devices | Out-Null
$dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'PCI\VEN_14C3&DEV_7961*'
if ($dev) { pnputil /restart-device "$($dev.InstanceId)" } else { 'Wi-Fi card not present yet: use Shut down (not Restart), then power on.' }
