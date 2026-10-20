# arch-bootstrap

Arch Linux workstation setup with archinstall, system packages, dotfiles, and DevPod. Takes a blank machine through installation and user configuration to a working desktop and container development environment.

## Part of the stateless workstation

The workstation setup is split into three repos, used in this order:

- arch-bootstrap (this repo): OS layer: Arch installation, system packages, and services.
- [dotfiles](https://github.com/MechHead777/dotfiles): User layer: shell, editor, and CLI tools with chezmoi and mise.
- [dev-container-playground](https://github.com/MechHead777/dev-container-playground): Project layer: per-project environments with DevPod and Docker.

## What's Included

| Step | Does |
|---|---|
| `packages` | Installs `packages/base.txt` everywhere, `desktop.txt` and `laptop.txt` when they apply, plus CPU microcode chosen by vendor |
| `system` | `pacman.conf` settings, the zram config, the `wheel` sudo rule, and adds your user to `docker` |
| `services` | Enables NetworkManager and docker |
| `dotfiles` | `chezmoi init --apply MechHead777/dotfiles`, which installs the CLI tools through mise |
| `devpod` | Installs DevPod, adds the docker provider, and sets the dotfiles options |
| `optional` | Offers interactive GUI and TUI package menus; run separately with `--only optional` |
| `finish` | SSH key, `gh auth login`, `gh ssh-key add`, and switches the dotfiles remote to SSH |

Hardware differences are detected, not configured: microcode follows the CPU vendor, and the laptop list is used only when a battery is present.

### Scope

| In scope | Out of scope |
|---|---|
| Disk layout, LUKS, bootloader, base system | Your data. Documents, the Obsidian vault, browser profiles, and SSH keys are not backed up here |
| pacman packages and system services | Per-project tools, which belong in each project's `mise.toml` |
| System files: `pacman.conf`, sudoers, groups, zram | User configs, which live in the dotfiles repo |
| Generating an SSH key and registering it with GitHub | Copying existing keys between machines. Each machine gets its own key |

"Stateless" here means the setup is reproducible, not the data. Back your data up separately.

## Setup

**Warning: phase 1 erases a disk. Read `archinstall/config.json` and confirm the target disk before running it. Test in a virtual machine first.**

### Phase 0: Prepare the Installer (on another computer)

First, download the Arch ISO and its signature file from an [official mirror](https://archlinux.org/download/).

Then, check the download against the checksum and the PGP signature. The exact commands and the current signing key are listed on the download page itself, next to the checksums, and the [ArchWiki installation guide](https://wiki.archlinux.org/title/Installation_guide#Verify_signature) covers the same steps.

> The signing key and the tools recommended for checking it change over time, so follow the download page rather than a copy of the commands kept here.

After it's verified, copy the ISO onto your Ventoy drive.

### Phase 1: Install Arch (from the live ISO)

First, boot the USB drive in UEFI mode and connect to the network. Ethernet comes up on its own, and Wi-Fi goes through `iwctl`.

Then, fetch the installer config:

```sh
curl -fsSLO https://raw.githubusercontent.com/MechHead777/arch-bootstrap/main/archinstall/config.json
```

Then, run the installer against it:

```sh
archinstall --config config.json
```

The config was exported by **archinstall 4.5**, then had its disk, hostname, and authentication sections removed. It was tested with archinstall 4.5 on the 2026.10.01 ISO; configuration formats can change between releases.

The config sets the locale, keymap, timezone, kernels, systemd-boot with unified kernel images, NetworkManager, Minimal profile, and the extra packages `git` and `curl`. Installer swap is disabled; bootstrap configures zram later.

Before selecting Install, complete these choices in the installer menus:

- **Disk configuration:** select the intended disk and the default layout with ext4. Use a single root partition, without a separate `/home`. Keep the EFI partition unencrypted and mounted at `/boot`.
- **Disk encryption:** choose LUKS, enter a passphrase, and select the root partition for encryption. Confirm encryption is enabled in the installation summary; leaving the passphrase empty can cancel encryption setup.
- **Hostname:** set it explicitly. Omitting it from the config leaves archinstall's default `archlinux`; it does not force a prompt.
- **Authentication:** create your user with sudo access and set the passwords you need. Keep passwords and exported credential files outside this repository.

Name this machine after its hardware, not its role (roles change). The digits are the install date, for example `inspiron-260917`.

Review the selected disk, ext4 root, encryption, and bootloader before confirming installation. In archinstall 4.5, filesystem and encryption settings are attached to a particular disk layout, so they must be selected manually in this portable configuration.

After it's finished, reboot into the new system and log in as your user.

### Phase 2: Bootstrap (on the new system)

First, install git:

```sh
sudo pacman -S --needed git
```

Then, clone this repo and run it:

```sh
git clone https://github.com/MechHead777/arch-bootstrap.git
cd arch-bootstrap
./bootstrap.sh
```

You're asked for your sudo password once at the start. Everything after that is unattended, and the whole run is logged to `~/.local/state/arch-bootstrap/`.

> On a new system, Docker group membership takes effect after a new login or reboot. If DevPod reports that the group is not active, log out and back in, then finish provider configuration from this repo:

```sh
./bootstrap.sh --only devpod
```

> If a step fails, the script prints the log path and the line that failed. Fix the problem, then re-run just that step with `./bootstrap.sh --only <step>`.

### Phase 3: Finish (interactive)

```sh
./bootstrap.sh finish
```

This generates an SSH key, registers it with GitHub, and switches your dotfiles remote from HTTPS to SSH so you can push.

> `gh auth login` prints a one-time code and a URL. Enter the code on any device with a browser, including your phone, so this works from a TTY.

Skip this phase on machines that never push to GitHub, such as test virtual machines.

After bootstrap is complete, follow the [Dev Container Playground workspace guide](https://github.com/MechHead777/dev-container-playground#setup) to clone a project, start it with `devpod up .`, and verify the container's dotfiles and tools.

### What stays manual

- Firmware settings: UEFI mode, and disabling secure boot
- Choosing the disk, and the LUKS, root, and user passwords
- Restoring your data
- Entering the `gh auth login` code in a browser
- Removing packages that drift out of the lists

## Usage

| Command | Does |
|---|---|
| `./bootstrap.sh` | Runs every unattended step in order |
| `./bootstrap.sh finish` | Runs the interactive phase |
| `./bootstrap.sh --only <step>` | Runs one step |
| `./bootstrap.sh --only optional` | Prompts for optional GUI and TUI applications |
| `./bootstrap.sh --skip <step>` | Runs everything except one step |
| `./bootstrap.sh --check` | Reports package drift and changes nothing |
| `DRY_RUN=1 ./bootstrap.sh` | Prints what would happen without doing it |

Every step is safe to run again, so running `./bootstrap.sh` on an existing machine brings it up to date with the repo.

### Package drift

`./bootstrap.sh --check` compares explicitly installed packages from `pacman -Qqe` against `packages/base.txt` and the desktop/laptop lists selected for the current profile. Set `PROFILE=base`, `PROFILE=desktop`, or `PROFILE=laptop` to override automatic profile detection.

It reports declared packages missing from that set and explicitly installed packages absent from the selected lists. Packages in `optional-gui.txt` and `optional-tui.txt`, plus `intel-ucode` and `amd-ucode`, are excluded from the extra-package report. It prints commands to address the differences and changes nothing itself.

Removal is always manual. A script that uninstalls packages it doesn't recognize is not one you can trust with a working machine.

## Verification

### Check the workstation

After bootstrap and a new login, check zram, Docker access, system services, and package drift:

```sh
swapon --show
docker ps
systemctl --failed
./bootstrap.sh --check
```

Docker should work without sudo, and the service check should report no failed units. Review package differences before installing or removing anything.

On a desktop or laptop, start the graphical session from the TTY:

```sh
niri-session
```

### Test in a VM

Test phase 1 in a virtual machine, never on hardware you care about. Check for Intel VT-x or AMD-V support with `lscpu | grep -E "vmx|svm"`.

First, create a disk and copy the UEFI firmware variables:

```sh
qemu-img create -f qcow2 arch-test.qcow2 40G
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd .
```

Then, boot the ISO:

```sh
qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.4m.fd \
  -drive file=arch-test.qcow2,if=virtio \
  -cdrom archlinux-x86_64.iso -boot d
```

> UEFI firmware is required, because systemd-boot does not work under BIOS. The `edk2-ovmf` package provides it.

For a niri desktop test, the VM also needs 3D acceleration. On the tested Arch host, install `qemu-ui-gtk`, `qemu-ui-opengl`, `qemu-hw-display-virtio-vga`, `qemu-hw-display-virtio-gpu`, `qemu-hw-display-virtio-vga-gl`, and `qemu-hw-display-virtio-gpu-gl` alongside the QEMU and OVMF packages. Add `-device virtio-vga-gl -display gtk,gl=on` to the QEMU command. Use `PROFILE=desktop ./bootstrap.sh` to exercise desktop packages in the VM. In the QEMU window, Ctrl+Alt+G toggles keyboard and mouse capture so desktop shortcuts reach the guest.

After the install succeeds, shut the VM down before taking a snapshot with `qemu-img snapshot -c installed arch-test.qcow2`. Phase 2 can then be tested repeatedly from that point with `qemu-img snapshot -a installed arch-test.qcow2`, also while the VM is shut down.

Preview phase 2 before applying it:

```sh
DRY_RUN=1 ./bootstrap.sh
```

When restarting the installed VM, boot from its disk rather than the installer ISO.

### Verified results

The fresh-install VM test verified encrypted root with an unencrypted EFI partition, booting both `linux` and `linux-lts`, a repeated desktop bootstrap run, active zram, Docker access without sudo, no failed system services, and no missing declared desktop packages. The niri session, terminal, application launcher, and LibreWolf browsing were also checked. DevPod's Docker provider was configured after re-login. A workspace built from `dev-container-playground`, accepted an SSH session as `vscode`, provided the mise tools, and reported no pending changes from `chezmoi status`. Interactive GitHub authentication was skipped.

## Repository Layout

| Path | Purpose |
|---|---|
| `bootstrap.sh` | Runs the steps in order and reports package drift |
| `lib.sh` | Shared helpers for commands, package lists, and hardware detection |
| `steps/` | Packages, system settings, services, dotfiles, DevPod, optional applications, and GitHub setup |
| `packages/base.txt` | Packages installed on every machine |
| `packages/desktop.txt` | Desktop packages, including niri, fuzzel, kitty, LibreWolf, and fonts |
| `packages/laptop.txt` | Laptop-specific packages |
| `packages/optional-gui.txt`, `packages/optional-tui.txt` | Packages offered by the optional step |
| `system/` | Configuration files copied into `/etc` |
| `archinstall/config.json` | Installer defaults; disk layout and encryption are selected manually |

## Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Installer | archinstall with a saved config | Maintained by Arch. Hand-written partitioning is several hundred lines of risky code with no upside here |
| Encryption | LUKS2 on the root partition | Passphrase based, so the drive is readable in any machine that has the passphrase. Nothing is tied to the motherboard, unlike TPM or secure boot |
| Filesystem | ext4 | Snapshots are the reason to pick btrfs, and this setup rebuilds from git instead |
| Bootloader | systemd-boot | UEFI only, so GRUB's features aren't needed. It also reads the kernel from the unencrypted EFI partition, which avoids GRUB's awkward LUKS2 support |
| Kernels | `linux` and `linux-lts` | A second boot entry to fall back to when a kernel update breaks hardware |
| Swap | zram only, half of RAM, via zram-generator | Compressed swap in RAM with no partition. Hibernation is skipped on purpose, since it breaks quietly on a rolling release |
| Login | TTY, then `niri-session` by hand | No display manager. A plain terminal login is useful on its own |
| Network | NetworkManager | Handles roaming Wi-Fi and captive portals, and `nmtui` is a working escape hatch. systemd-networkd suits fixed machines better |
| Browser | LibreWolf, from `extra` | Official repo, no AUR helper, no building. Its defaults, including clearing on close, are the wanted behavior |
| AUR | Not used | Everything needed is in the official repos |
| Secure boot | Not used | It complicates every kernel update, and LUKS already covers a stolen laptop |
| Hostname | Selected manually at install | Named after the hardware and the install date, for example `inspiron-260917`. Roles change, hardware doesn't |
| Language runtimes | None system-wide | node and python come from mise, per project |
