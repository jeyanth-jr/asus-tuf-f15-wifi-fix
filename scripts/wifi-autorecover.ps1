# Brings the MT7921 back after it drops off the PCIe bus. Run as SYSTEM by the scheduled task
# that 2-install-autorecover.ps1 creates (triggered by mtkwlex event 5002).
$log = Join-Path $PSScriptRoot 'autorecover.log'
function Write-Log($m) { "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $m | Add-Content $log }

Write-Log 'Wi-Fi failure event received.'
Start-Sleep -Seconds 5   # let the driver finish its own reset attempt first

for ($try = 1; $try -le 5; $try++) {
    $dev = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'PCI\VEN_14C3&DEV_7961*'
    if ($dev -and $dev.Status -eq 'OK') { Write-Log "Wi-Fi present and OK (attempt $try)."; exit 0 }
    if ($dev) {
        Write-Log "Wi-Fi present but status $($dev.Status); restarting device."
        pnputil /restart-device "$($dev.InstanceId)" | Out-Null
    } else {
        Write-Log 'Wi-Fi missing from the bus; rescanning hardware.'
        pnputil /scan-devices | Out-Null
    }
    Start-Sleep -Seconds (5 * $try)
}
Write-Log 'Wi-Fi did not come back after 5 attempts; a reboot is needed.'
exit 1
