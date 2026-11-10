# qdrnt

qdrnt is a CachyOS live ISO plus a preconfigured installer. It is not a
separate distro: the installed system is plain CachyOS (`os-release` and
`lsb-release` stay CachyOS) with a set of apps and settings applied at install
time. Changes here affect new installs only. Existing installs are never
updated by qdrnt.

## Layout

| Path | What |
|---|---|
| `archiso/` | Live ISO profile, a fork of [CachyOS-Live-ISO](https://github.com/CachyOS/CachyOS-Live-ISO) (remote `upstream`) |
| `calamares/` | Submodule: [mrquantumoff/cachyos-calamares](https://github.com/mrquantumoff/cachyos-calamares), branch `qdrnt` (forked from CachyOS `cachyos-dev`) |
| `pkgbuilds/qdrnt-calamares/` | Builds the installer package from the submodule's working tree |
| `scripts/build-packages.sh` | Builds `pkgbuilds/*` into `localrepo/` (the build-time `[qdrnt-local]` repo) |
| `scripts/wsl-build.sh`, `scripts/wsl-build.ps1` | Builds the ISO in the `cachyos` WSL distro |

## Live ISO

- **Desktop:** COSMIC. `liveuser` is logged in automatically through greetd's
  `initial_session` (`etc/greetd/qdrnt-live.toml` plus a drop-in for
  `cosmic-greeter.service`).
- **COSMIC live tweaks** (`etc/skel/.config/cosmic/`): screen-off and suspend
  timers are disabled, so the session never locks or sleeps. The dock pins
  "Install qdrnt" (`/usr/local/share/applications/qdrnt-install.desktop`),
  Helium, Files, Terminal, Text Editor and Settings.
- **Included:** Helium (no Firefox), zsh with `cachyos-zsh-config` as the live
  shell, Fira fonts, and gparted.
- **Not included:** CUDA, Proton VPN and Proton Mail, the office suites, and
  gaming packages. Those are only installed onto the target system.
- **ISO naming:** file `qdrnt-desktop-linux-<date>.iso`, volume label
  `QDRNT_<yyyymm>`, and qdrnt boot menu titles.
- **Keyring refresh:** `qdrnt-refresh-keyring` runs before Calamares starts. It
  syncs the clock over NTP, rebuilds `/etc/pacman.d/gnupg`, installs the latest
  `archlinux-keyring` and `cachyos-keyring`, and re-populates the keys. It
  retries up to 3 times.
- **Installer:** `qdrnt-calamares` is built into the ISO. `calamares-online.sh`
  no longer installs `cachyos-calamares-next` at launch, which would replace
  the qdrnt configuration.

## Installed system (set in `calamares/`)

- **Desktops:** COSMIC (default), KDE Plasma, or GNOME. All other desktops are
  removed.
- **Shell:** zsh with `cachyos-zsh-config`. Fish is removed. zsh is also the
  default for users added later (`/etc/default/useradd`).
- **Package groups** (shown in the installer, all selected by default):
  - **qdrnt applications:** helium-browser-bin, telegram-desktop, discord, zed,
    paru, proton-pass, proton-vpn-gtk-app, protonmail-bridge, obs-studio,
    gpu-screen-recorder with gpu-screen-recorder-ui, flatpak with flatseal,
    kdeconnect, btrfs-assistant, and the Fira fonts (ttf-fira-code,
    ttf-firacode-nerd, ttf-fira-mono, ttf-fira-sans, otf-fira-mono,
    otf-fira-sans, otf-firamono-nerd)
  - **qdrnt office:** euro-office-bin, libreoffice-fresh
  - **qdrnt containers:** docker, docker-compose, docker-buildx, distrobox
  - **qdrnt virtualization:** libvirt, qemu-desktop, virt-manager, dnsmasq,
    edk2-ovmf, swtpm
  - **qdrnt gaming:** cachyos-gaming-meta, cachyos-gaming-applications,
    epic-games-launcher-bin, protonplus, mangohud with lib32-mangohud, goverlay
- **The "Firefox and language package" group is removed.**
- **Zsh plugins page** (`packagechooser@zshplugins`, legacy method): the
  selection reaches `qdrnt-setup` as `${gs[packagechooser_zshplugins]}`,
  and it becomes the `plugins=(...)` line in `~/.zshrc`. The fork patches
  packagechooser so multi-select toggles on click and `default` can be a
  list.
- **zsh config:** `calamares/src/scripts/qdrnt.zsh` is installed to
  `/usr/local/share/qdrnt/qdrnt.zsh`. It sets up oh-my-zsh with the duellj
  theme, history settings, zsh-autosuggestions and zsh-syntax-highlighting.
  The live ISO gets the same file through the
  `90-qdrnt-live-zsh.hook` build hook.
- **The `qdrnt-setup` post-install script:**
  - Enables `docker.socket` and adds the user to the `docker` group. The group
    is also created up front in `users.conf`.
  - If an NVIDIA display controller is present (PCI vendor `0x10de`), installs
    `cuda`. When Docker is installed, it also installs
    `nvidia-container-toolkit` and runs `nvidia-ctk runtime configure`.
  - Enables `libvirtd.socket`, autostarts the default network, adds the user
    to `libvirt` and `kvm`, and allows `virbr0` in ufw.
  - Adds the Flathub remote system-wide.
  - Makes Helium the default browser (`/etc/xdg/mimeapps.list`, `BROWSER`).
- **Easy Anti-Cheat:** on UEFI with systemd-boot, Limine or rEFInd, `pacstrap`
  adds `linux-cachyos-eac`, `systemd-boot-cachyos-signed`,
  `cachyos-eac-signing-key`, `sbctl`, `sbsigntools`, `tpm2-tools`
  (`linux-cachyos-eac-zfs` on ZFS). `src/scripts/qdrnt-eac` runs after chwd and
  `bootloader-post-setup`. It installs the EAC NVIDIA/r8125 module packages,
  writes `$ESP/loader/entries/cachyos-eac.conf` from the bootloader's kernel
  command line plus CachyOS's EAC options, and makes it the default
  (systemd-boot: `loader.conf`; Limine/rEFInd: a "CachyOS EAC" firmware entry
  to `\EFI\cachyos-eac\systemd-bootx64.efi` first in BootOrder, plus a
  chainload entry back to Limine/rEFInd). Paths and labels match
  `eac-setup` from cachyos-settings, so `sudo eac-setup` later only enrolls the
  Secure Boot keys and signs the normal kernels. Not the default without TPM
  2.0, IOMMU, an EAC NVIDIA build, or with other DKMS modules installed.
- **Firewall:** CachyOS's ufw step opens KDE Connect automatically, because
  kdeconnect is installed.
- **Netinstall list:** read only from the bundled file, so it never pulls
  CachyOS's live list from GitHub.
- **multilib:** enabled on the target (the installer copies `pacman-more.conf`,
  and `qdrnt-setup` re-enables it if it is ever commented out).

## Build

On Windows, using the `cachyos` WSL distro:

```powershell
git submodule update --init
.\scripts\wsl-build.ps1        # ISO and checksums land in .\out
```

- `wsl-build.sh` runs as root in WSL and runs `pacman -Syu` on the WSL distro
  to install archiso and the build tools.
- It copies the repo to `/var/tmp/qdrnt-build/src`, restores file modes and
  symlinks from the git index, builds `qdrnt-calamares` into `localrepo/`, runs
  `buildiso.sh -p desktop`, and copies the results back to `out/`.

Add `QDRNT_DOCKER=1` (in WSL: `sudo QDRNT_DOCKER=1 scripts/wsl-build.sh`) to
build in a clean `cachyos/cachyos` container instead of on the WSL system. This
is the same path CI uses, and it leaves the WSL packages alone.

On a native Arch or CachyOS host:

```sh
sudo scripts/build-packages.sh && sudo ./buildiso.sh -p desktop
```

## Monthly releases

`.github/workflows/monthly-iso.yml` runs at 04:00 UTC on the 1st of each month
and can also be started by hand (Actions, then "Run workflow"). It builds in a
privileged `cachyos/cachyos` container (`scripts/ci-build.sh`) and publishes a
GitHub release tagged `vYYYY.MM.DD`. GitHub caps release assets at 2 GiB, so
the ISO is uploaded as `.partNN` pieces plus a `.sha256` of the whole ISO.
Rebuild it with `cat *.iso.part* > qdrnt.iso`. When the SourceForge secrets are
set, the whole ISO is also uploaded there and linked from the release notes.

## Updating from upstream

- **Live ISO:** `git fetch upstream && git merge upstream/master`. Expect
  conflicts in `packages_desktop.x86_64` and `util-iso.sh`.
- **Installer:** in `calamares/`, run `git fetch upstream && git rebase
  upstream/cachyos-dev`. Add the remote first with `git remote add upstream
  https://github.com/CachyOS/cachyos-calamares`. Then push to the fork and
  commit the new submodule pointer here.
- **Installer package:** compare `pkgbuilds/qdrnt-calamares/PKGBUILD` against
  CachyOS-PKGBUILDS `cachyos-calamares/PKGBUILD` for dependency changes.

## Ideas not done yet

- **Snapshots:** snapper with snap-pac, or limine-snapper-sync (btrfs-assistant
  is already installed).
- **More apps:** heroic-games-launcher, vesktop (Discord with working Wayland
  screen share), localsend, and podman-desktop.
