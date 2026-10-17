# ASUS TUF F15 Wi-Fi disappearing: fix (MediaTek MT7921)

**ASUS TUF Gaming F15 Wi-Fi keeps disappearing on Windows 11/10?** There's no Wi-Fi icon, the adapter vanishes from Device Manager, and it only comes back after sleep, a restart or some random amount of time. This is a widely reported problem with the TUF F15, and it comes from the **MediaTek MT7921 (Wi-Fi 6)** card that ASUS fitted in many of these laptops.

If you've already tried the usual advice (new driver, BIOS update, MyASUS settings, power plan tweaks, unticking *Allow the computer to turn off this device*) and it still drops, this repo covers what's left. It turns off the Wi-Fi driver's **hidden** low-power settings, which none of those menus reach, and adds an optional auto-recovery task.

**Tested on:** ASUS TUF Gaming F15 **FX506LHB**, BIOS 311, Windows 11, MediaTek driver **3.0.1.1314**.
**Likely applies to:** other TUF F15 / F17 / A15 / A17 models, and any laptop with an MT7921 card (`PCI\VEN_14C3&DEV_7961`). Only the FX506LHB has been verified.

> [!WARNING]
> This is an unofficial workaround, not ASUS or MediaTek guidance. It edits the Wi-Fi driver's registry settings. The script backs them up first and the change can be undone, but use it at your own risk.

---

## Contents

- [Is this your problem?](#is-this-your-problem)
- [Why the TUF F15 Wi-Fi drops](#why-the-tuf-f15-wi-fi-drops)
- [The fix](#the-fix)
- [Optional: auto-recovery](#optional-auto-recovery)
- [Check that it worked](#check-that-it-worked)
- [Undo](#undo)
- [Safety and trade-offs](#safety-and-trade-offs)
- [How the hidden settings were found](#how-the-hidden-settings-were-found)
- [Files](#files)

---

## Is this your problem?

First, confirm your TUF F15 has the MediaTek card. In Device Manager, under *Network adapters*, look for **MediaTek Wi-Fi 6 MT7921 Wireless LAN Card**. Some TUF F15s ship with an Intel or Realtek card instead, and this fix isn't for those.

While the Wi-Fi is gone, run this in PowerShell (no admin needed):

```powershell
Get-PnpDevice -Class Net | Where-Object FriendlyName -match 'MT7921' | Select-Object Status, Present, FriendlyName
```

`Present : False` means the card has dropped off the PCIe bus entirely. Windows can't see the hardware at all, which is different from an ordinary Wi-Fi disconnect.

Then check the **System** log in Event Viewer. On an affected TUF F15 you'll see this sequence before every drop:

| Time | Source | Event | Meaning |
|---|---|---|---|
| T | `WHEA-Logger` | 17, *A corrected hardware error has occurred*, component **PCI Express Root Port** | The PCIe link to the Wi-Fi card glitched |
| T + ~6 s | `mtkwlex` | 5002, *adapter is not functioning properly* | The driver gave up on the card |
| T + ~6 s | `NDIS` | 10317, *miniport … Fatal error* | Windows tore down the adapter |

Or count the driver failures directly:

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='mtkwlex'; Id=5002} -MaxEvents 10
```

The test laptop had about 20 of these in 30 days, roughly one drop every day and a half.

## Why the TUF F15 Wi-Fi drops

When the card is idle, the MT7921 driver saves power in two ways:

1. **Firmware deep sleep:** the driver hands control of the chip to the card's own firmware, which puts it to sleep.
2. **PCIe L1 substates (L1.1 / L1.2):** the link between the card and the laptop drops into its deepest low-power state.

Waking up means reversing both. On the TUF F15 the card sometimes doesn't wake: the PCIe link errors out (the WHEA event), the driver's recovery fails (5002), and Windows loses the device until the laptop is power-cycled.

The Windows power plan setting **PCI Express > Link State Power Management** doesn't necessarily stop this, because the driver and firmware manage these states themselves. On the test TUF F15, that setting and *Wireless Adapter > Power Saving Mode* were both already off when the drops were happening.

## The fix

The driver reads several settings from its registry key that aren't shown in Device Manager's *Advanced* tab. This fix sets four of them to `0`:

| Setting | Default | Controls (inferred from the name) |
|---|---|---|
| `LowPowerEnable` | `1` | Firmware deep sleep / power-control handoff |
| `DeInitLP` | `1` | Low-power mode when the driver de-initializes |
| `L1SSModeLevel` | not set | PCIe L1 substates |
| `PsEnable` | not set | Driver power save |

They live under:

```
HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\<NNNN>
```

where `<NNNN>` is the subkey whose `MatchingDeviceId` starts with `PCI\VEN_14C3&DEV_7961`. The script finds it for you.

### Steps

1. Download this repo (*Code > Download ZIP*) and extract it, for example to `C:\asus-tuf-f15-wifi-fix`.
2. Open **PowerShell as administrator**: Start, type *PowerShell*, right-click it and choose *Run as administrator*.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\1-disable-mt7921-lowpower.ps1"
   ```

   It saves `scripts\mt7921-backup.reg` first, then prints each change, for example `LowPowerEnable   1 -> 0`.
4. **Shut down** (not *Restart*), wait a few seconds, then power on. A full shutdown power-cycles the card, which brings it back if it's currently missing and makes the driver load the new settings.

> `-ExecutionPolicy Bypass` applies to this one command only. It doesn't change your system's execution policy.

## Optional: auto-recovery

This is a safety net that's worth installing even if the fix works. It creates a scheduled task that fires the moment the driver logs event `5002`, then rescans hardware or restarts the card. It tries up to 5 times over about a minute, instead of leaving you offline until the next reboot.

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\2-install-autorecover.ps1"
```

- The task runs as **SYSTEM**, so the installer copies its script to `C:\Program Files\MT7921-autorecover\`, which only administrators can change. The task never runs a file from your user folders.
- Each attempt is logged to `C:\Program Files\MT7921-autorecover\autorecover.log`.
- To remove it, run `scripts\2-uninstall-autorecover.ps1` as administrator.

## Check that it worked

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\check-status.ps1"
```

It shows whether the card is present, the four settings, and how many driver failures happened in the last 30 days. It's read-only and doesn't need admin.

Give it a few days. If no new `5002` events appear after the change, the fix is working. If they still appear but the auto-recovery log shows the card coming back, the safety net is covering it.

## Undo

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\1-undo.ps1"
```

This restores the original values from `scripts\mt7921-backup.reg` and removes the settings that weren't there before. Then shut down and power on.

## Safety and trade-offs

**What it touches:** four string values in the Wi-Fi driver's own registry key. It doesn't modify any driver files, firmware or BIOS, so driver signing and Secure Boot are unaffected.

**What it costs:** the card no longer deep-sleeps when idle, so expect somewhat higher battery drain and heat on battery power. This hasn't been measured.

**What's uncertain:**
- The meaning of each setting is **inferred from its name**, not from decompiled code. The result is what counts, so verify it with `check-status.ps1` over a few days.
- **Driver updates** (including through MyASUS or Windows Update) **can reset these settings.** If the drops come back after an update, run the fix again.
- Only tested on one TUF F15 model (FX506LHB) with one driver version. If it works on yours, please open an issue with your model and driver version.

**Keep `mt7921-backup.reg` private.** It's a copy of your driver's registry key and contains your adapter's MAC address and recently connected network data. `.gitignore` excludes it, so don't commit or share it.

## How the hidden settings were found

1. The driver's install file (`C:\Windows\INF\oem*.inf`, the one for MT7921) sets `LowPowerEnable=1`, `DeInitLP=1` and `ConnIdleTimeForL1=0`, none of which appear in Device Manager.
2. Scanning the driver binary `C:\Windows\System32\drivers\mtkwl6ex.sys` for UTF-16 strings shows its registry-name table. These are the value names the driver passes to Windows when it reads its configuration. That table includes `PsEnable`, `ForcePS`, `LowPowerEnable`, `LPSupportNonMS`, `DeInitLP` and `L1SSModeLevel`, so the driver reads them even though the INF doesn't set them all.
3. This matches the common fix for the same chip on Linux: turning off ASPM/L1 substates and runtime power management for `mt7921e`.

This was a static string scan, not a decompilation. A full answer to what each value does would need a disassembler such as Ghidra or IDA.

## Files

| File | Admin | What it does |
|---|---|---|
| `scripts/1-disable-mt7921-lowpower.ps1` | yes | Backs up the driver key, sets the four values to `0`, restarts the card |
| `scripts/1-undo.ps1` | yes | Restores the backup |
| `scripts/2-install-autorecover.ps1` | yes | Installs the auto-recovery task into `Program Files` |
| `scripts/2-uninstall-autorecover.ps1` | yes | Removes the task and its files |
| `scripts/wifi-autorecover.ps1` | n/a | The recovery script the task runs (rescans or restarts the card) |
| `scripts/check-status.ps1` | no | Read-only status: card presence, settings, recent failures |

## License

[MIT](LICENSE). Provided as is, with no warranty.
