# predator-linux

Machine-specific setup for the **Acer Predator PHN16S-71** on CachyOS/Arch Linux.

Downloads and installs [DAMX (DivAcerManagerMax)](https://github.com/PXDiv/Div-Acer-Manager-Max) — the fan/thermal profile controller for Acer Predator laptops — with the hardware-specific workarounds required for this model.

## What it does

- Installs kernel headers and builds the **linuwu-sense** driver from source
- Applies `options linuwu_sense predator_v4=1` — required for the PHN16S v4 WMI protocol
- Installs the **DAMX daemon** (background service on `/var/run/DAMX.sock`)
- Installs the **DAMX GUI** (`DAMX` command / app launcher)
- Enables `damx-daemon` and `linuwu_sense` systemd services
- Reminds you to add `ibt=off` to kernel parameters (required to prevent crashes on this model)

## Requirements

- CachyOS or Arch Linux with `linux-cachyos` kernel
- `paru` or `yay` not needed — everything is downloaded from GitHub
- Internet connection (fetches latest DAMX release automatically)

## Usage

```bash
curl -O https://raw.githubusercontent.com/tonyrdz-coder/predator-linux/main/setup.sh
sudo bash setup.sh
```

Or clone and run:

```bash
git clone https://github.com/tonyrdz-coder/predator-linux.git
sudo bash predator-linux/setup.sh
```

After running, add `ibt=off` to your kernel parameters (see output at end of script).

## Notes

- Only `low-power` and `balanced` thermal profiles work on **BIOS V1.26**. Other profiles return `ENOTSUP`. Update BIOS when a fix is available.
- RGB control is not supported — the WMI LED methods hang on BIOS V1.26. Do not attempt.
- `damx-waybar` and `damx-cycle` helper scripts are part of [mycachy](https://github.com/tonyrdz-coder/mycachy) (the desktop config repo).

## Hardware

Acer Predator PHN16S-71 — Intel Core i9 13th gen + NVIDIA RTX hybrid GPU, CachyOS.
