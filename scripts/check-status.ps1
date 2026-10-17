# Read-only: shows whether the MT7921 is present, the current low-power settings, and recent driver failures.
# Works without admin.
$dev = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'PCI\VEN_14C3&DEV_7961*' | Select-Object -First 1
if (-not $dev) { 'No MediaTek MT7921 found on this PC.'; exit 1 }
"Wi-Fi card: $($dev.FriendlyName)"
"  Present: $($dev.Present)   Status: $($dev.Status)"

$classRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
$key = Get-ChildItem $classRoot -ErrorAction SilentlyContinue |
    Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).MatchingDeviceId -like 'PCI\VEN_14C3&DEV_7961*' } |
    Select-Object -First 1
if ($key) {
    $p = Get-ItemProperty $key.PSPath
    "Driver: $($p.DriverVersion) ($($p.DriverDate))"
    foreach ($name in 'LowPowerEnable', 'DeInitLP', 'L1SSModeLevel', 'PsEnable') {
        "  {0,-16} {1}" -f $name, ($(if ($null -eq $p.$name) { '(unset)' } else { $p.$name }))
    }
}

$events = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'mtkwlex'; Id = 5002; StartTime = (Get-Date).AddDays(-30) } -ErrorAction SilentlyContinue
"Driver failures (event 5002) in the last 30 days: $(@($events).Count)"
$events | Select-Object -First 5 | ForEach-Object { "  $($_.TimeCreated)" }
