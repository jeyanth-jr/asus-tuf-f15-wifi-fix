# ASUS TUF F15 Wi-Fi disappearing: diagnosis, workarounds, real fix (MediaTek MT7921)

**ASUS TUF Gaming F15 Wi-Fi keeps disappearing on Windows 11/10?** There's no Wi-Fi icon, the adapter vanishes from Device Manager, and it only comes back after a restart, a shutdown or some random amount of time. This is a widely reported problem with the TUF F15, and it comes from the **MediaTek MT7921 (Wi-Fi 6)** card that ASUS fitted in many of these laptops.

This repo documents what was tested on one TUF F15: how to confirm you have this exact problem, what worked, and what didn't.

**Tested on:** ASUS TUF Gaming F15 **FX506LHB**, BIOS 311, Windows 11, MediaTek driver **3.0.1.1314**.
**Likely applies to:** other TUF F15 / F17 / A15 / A17 models, and any laptop with an MT7921 card (`PCI\VEN_14C3&DEV_7961`). Only the FX506LHB has been verified.

> [!IMPORTANT]
> **Short version:** no software setting found here stops the drops. On the test laptop the card kept falling off after waking from **Sleep**, and once it's gone only cutting its power brings it back.
>
> - **Workaround:** use **Hibernate instead of Sleep** ([script](#workaround-hibernate-instead-of-sleep)).
> - **Real fix:** **replace the Wi-Fi card**, for example with an Intel AX210 ([details](#the-real-fix-replace-the-card)).
>
> An earlier version of this README said the registry tweak below fixed the problem. It didn't, and this version corrects that.

> [!WARNING]
> These are unofficial workarounds, not ASUS or MediaTek guidance. Every script backs up what it changes and has an undo, but use them at your own risk.

---

## Contents

- [Is this your problem?](#is-this-your-problem)
- [Why the TUF F15 Wi-Fi drops](#why-the-tuf-f15-wi-fi-drops)
- [What was tried](#what-was-tried)
- [Workaround: Hibernate instead of Sleep](#workaround-hibernate-instead-of-sleep)
- [The real fix: replace the card](#the-real-fix-replace-the-card)
- [Optional: auto-recovery](#optional-auto-recovery)
- [Optional: driver low-power tweak (didn't help here)](#optional-driver-low-power-tweak-didnt-help-here)
- [Check status](#check-status)
- [Safety](#safety)
- [How the hidden settings were found](#how-the-hidden-settings-were-found)
- [Files](#files)

---

## Is this your problem?

First, confirm your TUF F15 has the MediaTek card. In Device Manager, under *Network adapters*, look for **MediaTek Wi-Fi 6 MT7921 Wireless LAN Card**. Some TUF F15s ship with an Intel or Realtek card instead, and none of this applies to them.

While the Wi-Fi is gone, run this in PowerShell (no admin needed):

```powershell
Get-PnpDevice -Class Net | Where-Object FriendlyName -match 'MT7921' | Select-Object Status, Present, FriendlyName
```

`Present : False` means the card has dropped off the PCIe bus entirely. Windows can't see the hardware at all, which is different from an ordinary Wi-Fi disconnect.

Then check the **System** log in Event Viewer. On the test TUF F15 every drop looked like this:

| Time | Source | Event | Meaning |
|---|---|---|---|
| T | `WHEA-Logger` | 17, *A corrected hardware error has occurred*, component **PCI Express Root Port** | The PCIe link to the Wi-Fi card glitched |
| T + ~6 s | `mtkwlex` | 5002, *adapter is not functioning properly* | The driver gave up on the card |
| T + ~6 s | `NDIS` | 10317, *miniport … Fatal error* | Windows tore down the adapter |

Sometimes, especially after waking from sleep, only the `NDIS 10317` event appears.

Or run the included status check, which counts the driver failures for you: see [Check status](#check-status).

## Why the TUF F15 Wi-Fi drops

Every PCIe error on the test laptop came from **one** place: *Intel PCI Express Root Port #14*, the slot the Wi-Fi card is connected to. Nothing else in the system was reporting them.

| Period | Corrected PCIe errors on that slot |
|---|---|
| A normal day | 1 to 135 |
| The day after waking from sleep several times | **2,184** |

Most of the drops happened shortly after the laptop **woke from Sleep (S3)**. During sleep the card is put into a low-power state, and on wake its PCIe link has to come back up. On this laptop it often doesn't, or it comes up unstable and fails a few minutes later. When that happens the card disappears from the bus.

A link that throws thousands of corrected errors in a day points to a **signal or hardware problem** between the card and the slot: the card itself, its firmware, or the connection. Windows settings can't fully fix that. They can only avoid triggering it.

## What was tried

| Attempt | Result |
|---|---|
| Newer driver, BIOS update, MyASUS settings | Didn't stop the drops (tried before this repo) |
| Power plan: PCIe *Link State Power Management* Off, Wi-Fi *Power Saving* Max Performance | Already set; drops continued |
| Device Manager: untick *Allow the computer to turn off this device* | Already set; drops continued |
| [Driver low-power tweak](#optional-driver-low-power-tweak-didnt-help-here) (4 hidden registry values to `0`) | **Didn't help.** Drops continued after waking from sleep |
| `pnputil /scan-devices` after a drop | Brings the card back only if it's still on the bus. Once `Present = False`, it does nothing |
| Restarting the PCIe root port (`pnputil /restart-device` on the slot) | **Didn't bring the card back** |
| **Shut down, then power on** | **Always brought the card back** |
| **Hibernate, then resume** | Powers the card off completely, the same as a shutdown |

The pattern: once the card has dropped, **only removing its power** gets it back. That's why the workaround is Hibernate.

## Workaround: Hibernate instead of Sleep

Sleep (S3) keeps the card powered and is when it fails to come back. Hibernate saves your session to disk and powers the laptop off completely, so the card is reset every time. Resuming takes a few seconds longer than from Sleep, but your apps and windows stay where you left them.

1. Download this repo (*Code > Download ZIP*) and extract it, for example to `C:\asus-tuf-f15-wifi-fix`.
2. Open **PowerShell as administrator**: Start, type *PowerShell*, right-click it and choose *Run as administrator*.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\3-use-hibernate.ps1"
   ```

It changes your **active** power plan, both plugged in and on battery:

| Setting | New value |
|---|---|
| Closing the lid | Hibernate |
| Power button, sleep button | Hibernate |
| Start menu power button's *Sleep* action | Hibernate |
| Sleep after idle | Never |
| Hibernate after idle | 30 minutes |

It saves your current values to `scripts\power-backup.json` first. To undo:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\3-undo-hibernate.ps1"
```

> `-ExecutionPolicy Bypass` applies to this one command only. It doesn't change your system's execution policy.

**If the Wi-Fi is already gone right now:** Hibernate or Shut down (not *Restart*), wait a few seconds, then power on.

## The real fix: replace the card

The Wi-Fi card in the TUF F15 is normally a standard, removable **M.2 2230** card (check yours when you open the panel), so you can swap it. This step hasn't been done on the test laptop yet. The usual replacement is an **Intel Wi-Fi 6E AX210** (or AX200), which is widely used, has solid Windows drivers, and includes Bluetooth.

- It costs around US$15 to 25, and takes a small Phillips screwdriver and about 20 minutes: remove the bottom panel, unplug the two antenna leads, unscrew the old card, fit the new one and reconnect the antennas.
- Install Intel's Wi-Fi and Bluetooth drivers afterwards.
- Check your warranty first. Opening the bottom panel is usually allowed, but confirm for your region.
- Before buying, try reseating the existing card and its antenna leads. A poorly seated card can also cause PCIe errors.

## Optional: auto-recovery

Some failures leave the card on the bus. In those cases a hardware rescan or a device restart brings it back in seconds. This creates a scheduled task that does that automatically when the driver logs a failure (`mtkwlex 5002` or `NDIS 10317`):

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\2-install-autorecover.ps1"
```

- If the card has fully dropped off the bus, this can't help, and the log says a power cycle is needed.
- The task runs as **SYSTEM**, so the installer copies its script to `C:\Program Files\MT7921-autorecover\`, which only administrators can change. Never point a SYSTEM task at a script in your user folders: any program running as you could edit it and gain full control of the PC.
- Each attempt is logged to `C:\Program Files\MT7921-autorecover\autorecover.log`.
- To remove it, run `scripts\2-uninstall-autorecover.ps1` as administrator.

## Optional: driver low-power tweak (didn't help here)

This is kept for reference and for other models, where it may behave differently. **On the test FX506LHB it did not stop the drops.**

The MT7921 driver reads several settings from its registry key that aren't shown in Device Manager. This script sets four of them to `0`:

| Setting | Default | Controls (inferred from the name) |
|---|---|---|
| `LowPowerEnable` | `1` | Firmware deep sleep / power-control handoff |
| `DeInitLP` | `1` | Low-power mode when the driver de-initializes |
| `L1SSModeLevel` | not set | PCIe L1 substates |
| `PsEnable` | not set | Driver power save |

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\1-disable-mt7921-lowpower.ps1"
```

It saves `scripts\mt7921-backup.reg` first. Undo with `scripts\1-undo.ps1`, then shut down and power on. With these off, the card no longer deep-sleeps when idle, which may cost some battery life. Driver updates can reset the values.

## Check status

```powershell
powershell -ExecutionPolicy Bypass -File "C:\asus-tuf-f15-wifi-fix\scripts\check-status.ps1"
```

It shows whether the card is present, the four driver settings, and how many driver failures happened in the last 30 days. It's read-only and doesn't need admin.

## Safety

- **Nothing here modifies driver files, firmware or the BIOS.** The scripts only change power-plan values, four values in the Wi-Fi driver's registry key, and a scheduled task, and each of those has an undo.
- **Keep `mt7921-backup.reg` private.** It's a copy of your driver's registry key and contains your adapter's MAC address and recently connected network data. `.gitignore` excludes it (and `power-backup.json`), so don't commit or share it.
- **Everything here was verified on one laptop** with one driver version. If you try it on another model, please open an issue with your model, driver version and result.

## How the hidden settings were found

1. The driver's install file (`C:\Windows\INF\oem*.inf`, the one for MT7921) sets `LowPowerEnable=1`, `DeInitLP=1` and `ConnIdleTimeForL1=0`, none of which appear in Device Manager.
2. Scanning the driver binary `C:\Windows\System32\drivers\mtkwl6ex.sys` for UTF-16 strings shows its registry-name table. These are the value names the driver passes to Windows when it reads its configuration. That table includes `PsEnable`, `ForcePS`, `LowPowerEnable`, `LPSupportNonMS`, `DeInitLP` and `L1SSModeLevel`.
3. These match the common fix for the same chip on Linux: turning off ASPM/L1 substates and runtime power management for `mt7921e`.

This was a static string scan, not a decompilation, so what each value does is inferred from its name. A full answer would need a disassembler such as Ghidra or IDA.

## Files

| File | Admin | What it does |
|---|---|---|
| `scripts/3-use-hibernate.ps1` | yes | **Workaround:** lid and buttons hibernate instead of sleeping (backs up your settings) |
| `scripts/3-undo-hibernate.ps1` | yes | Restores your previous power settings |
| `scripts/2-install-autorecover.ps1` | yes | Installs the auto-recovery task into `Program Files` |
| `scripts/2-uninstall-autorecover.ps1` | yes | Removes the task and its files |
| `scripts/wifi-autorecover.ps1` | n/a | The recovery script the task runs (rescans or restarts the card) |
| `scripts/1-disable-mt7921-lowpower.ps1` | yes | Driver low-power tweak (didn't help on the test laptop) |
| `scripts/1-undo.ps1` | yes | Restores the driver settings from the backup |
| `scripts/check-status.ps1` | no | Read-only status: card presence, settings, recent failures |

## License

[MIT](LICENSE). Provided as is, with no warranty.
