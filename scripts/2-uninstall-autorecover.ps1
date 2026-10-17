# Run in an ADMIN PowerShell: removes the "MT7921 Wi-Fi auto-recover" task and its installed script.
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Not running as administrator. Right-click PowerShell > Run as administrator, then run this again.'
}
schtasks /delete /tn 'MT7921 Wi-Fi auto-recover' /f
Remove-Item (Join-Path $env:ProgramFiles 'MT7921-autorecover') -Recurse -Force -ErrorAction SilentlyContinue
'Auto-recover removed.'
