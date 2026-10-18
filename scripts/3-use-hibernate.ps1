# Run in an ADMIN PowerShell:  powershell -ExecutionPolicy Bypass -File .\scripts\3-use-hibernate.ps1
# Workaround: use Hibernate instead of Sleep (S3). Hibernate powers the Wi-Fi card off completely,
# which is the only thing found to bring an MT7921 back once it has dropped off the PCIe bus.
#
# Changes the ACTIVE power plan only, for both plugged in (AC) and battery (DC):
#   lid close, power button, sleep button and Start menu power button -> Hibernate;
#   idle sleep -> off; idle hibernate -> 30 min.
# Saves the previous values to power-backup.json first; undo with 3-undo-hibernate.ps1.
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not running as administrator. Right-click PowerShell > Run as administrator, then run this again.'
}

$targets = @(
    @{ Sub = 'SUB_BUTTONS'; Setting = 'LIDACTION';     Value = 2 }     # 2 = Hibernate
    @{ Sub = 'SUB_BUTTONS'; Setting = 'PBUTTONACTION'; Value = 2 }
    @{ Sub = 'SUB_BUTTONS'; Setting = 'SBUTTONACTION'; Value = 2 }
    @{ Sub = 'SUB_BUTTONS'; Setting = 'UIBUTTON_ACTION'; Value = 1 }   # Start menu button: 1 = Hibernate
    @{ Sub = 'SUB_SLEEP';   Setting = 'STANDBYIDLE';   Value = 0 }     # never sleep when idle
    @{ Sub = 'SUB_SLEEP';   Setting = 'HIBERNATEIDLE'; Value = 1800 }  # hibernate after 30 min idle
)

function Get-PowerIndex($sub, $setting) {
    # /qh also lists settings the plan hides (lid and button actions often are)
    $out = powercfg /qh SCHEME_CURRENT $sub $setting | Out-String
    $ac = [regex]::Match($out, 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)')
    $dc = [regex]::Match($out, 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)')
    if (-not $ac.Success) { return $null }   # setting not present on this plan
    [pscustomobject]@{ AC = [Convert]::ToInt32($ac.Groups[1].Value, 16); DC = [Convert]::ToInt32($dc.Groups[1].Value, 16) }
}

powercfg /hibernate on

$backup = Join-Path $PSScriptRoot 'power-backup.json'
if (-not (Test-Path $backup)) {
    $saved = foreach ($t in $targets) {
        $cur = Get-PowerIndex $t.Sub $t.Setting
        if ($cur) { [pscustomobject]@{ Sub = $t.Sub; Setting = $t.Setting; AC = $cur.AC; DC = $cur.DC } }
    }
    $saved | ConvertTo-Json | Set-Content $backup -Encoding UTF8
    "Backup written: $backup"
} else { "Backup already exists, keeping original: $backup" }

foreach ($t in $targets) {
    if (-not (Get-PowerIndex $t.Sub $t.Setting)) { "{0,-14} not available on this plan, skipped" -f $t.Setting; continue }
    powercfg /setacvalueindex SCHEME_CURRENT $t.Sub $t.Setting $t.Value
    powercfg /setdcvalueindex SCHEME_CURRENT $t.Sub $t.Setting $t.Value
    "{0,-14} -> {1}" -f $t.Setting, $t.Value
}
powercfg /setactive SCHEME_CURRENT
'Done. Closing the lid or pressing the power button now hibernates instead of sleeping.'
