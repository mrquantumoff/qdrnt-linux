# qdrnt

qdrnt is a CachyOS live ISO with a preconfigured installer. The system it
installs is ordinary CachyOS: it uses the CachyOS repos, CachyOS updates, and
CachyOS `os-release`/`lsb-release`. qdrnt changes only what is on the ISO and
what the installer sets up on day one.

It is built from [CachyOS-Live-ISO](https://github.com/CachyOS/CachyOS-Live-ISO)
and a fork of [cachyos-calamares](https://github.com/CachyOS/cachyos-calamares)
([mrquantumoff/cachyos-calamares](https://github.com/mrquantumoff/cachyos-calamares),
branch `qdrnt`, included here as the `calamares/` submodule).

**Download:** see [Releases](https://github.com/mrquantumoff/qdrnt-linux/releases).
A new ISO is built automatically on the 1st of every month.

## Differences from the stock CachyOS ISO

### Live session

| | CachyOS | qdrnt |
|---|---|---|
| Desktop | KDE Plasma (Plasma Login Manager) | **COSMIC** (cosmic-greeter, greetd autologin) |
| Browser | Firefox | **Helium** |
| Live shell | bash, plus fish config | **zsh**: oh-my-zsh with the **duellj** theme, autosuggestions, syntax highlighting |
| Fonts | Noto, DejaVu, Liberation… | Same, plus **Fira** (Code, Mono, Sans, Nerd) |
| Idle / lock | Plasma defaults | **Screen-off and suspend disabled**, so the live session never sleeps |
| Dock | – | **"Install qdrnt"**, Helium, Files, Terminal, Editor, Settings |
| Installer source | Downloads `cachyos-calamares-next` from the repo when launched | **Built into the ISO** (`qdrnt-calamares`, from the submodule), so it can't be swapped out |
| Keyring | Re-initialised before the installer | `qdrnt-refresh-keyring`: **waits for NTP sync first**, rebuilds the keyring, installs the newest keyring packages, retries 3× |
| ISO name / label / boot menu | `cachyos-…`, `COS_…`, "CachyOS" | `qdrnt-…`, `QDRNT_…`, "qdrnt" |

### Installer

| | CachyOS | qdrnt |
|---|---|---|
| Desktop choices | ~17 desktops and window managers, KDE is the default | **COSMIC (default), KDE Plasma, GNOME** only |
| Package list | Downloaded from CachyOS's GitHub at install time | **Bundled** with the installer (reproducible) |
| User shell | fish | **zsh** (also the default for users added later) |
| Shell setup | powerlevel10k prompt | **oh-my-zsh + duellj** theme, zsh-autosuggestions, zsh-syntax-highlighting, and a new **"Zsh plugins" page** to pick oh-my-zsh plugins |
| Browser | Firefox + language pack | **Helium**, set as the default browser |
| Groups | No `docker` or `libvirt` setup | User is added to **`docker`**, **`libvirt`** and **`kvm`** |
| Multilib | Enabled | Enabled, and **re-checked** after install |

Extra package groups, all selected by default (you can untick them):

- **qdrnt applications:** Helium, Telegram, Discord, Zed, paru, Proton Pass,
  Proton VPN, Proton Mail Bridge, OBS Studio, GPU Screen Recorder + UI,
  Flatpak + Flatseal, KDE Connect, Btrfs Assistant, Fira fonts
- **qdrnt office:** Euro-Office (`euro-office-bin`), LibreOffice Fresh
- **qdrnt containers:** Docker (+ compose, buildx), Distrobox
- **qdrnt virtualization:** libvirt, QEMU (`qemu-desktop`), virt-manager,
  dnsmasq, OVMF (UEFI guests), swtpm (TPM for Windows 11 guests)
- **qdrnt gaming:** `cachyos-gaming-meta`, `cachyos-gaming-applications`, Epic
  Games Launcher, ProtonPlus, MangoHud (+ lib32), GOverlay

Post-install setup (`qdrnt-setup`):

- **Docker:** enables `docker.socket` and adds the new user to the `docker`
  group.
- **libvirt:** enables `libvirtd.socket`, autostarts the `default` NAT
  network, adds the user to `libvirt` and `kvm`, and sets
  `LIBVIRT_DEFAULT_URI=qemu:///system`. The ufw step lets traffic through
  `virbr0`, so guests get DHCP and NAT.
- **zsh:** installs `/usr/local/share/qdrnt/qdrnt.zsh`. It writes `~/.zshrc`
  (and `/etc/skel/.zshrc`) with the plugins picked on the "Zsh plugins" page.
  Edit the `plugins=(...)` line later to change them.
- **NVIDIA GPU detected:** installs **CUDA**. If Docker is installed, also
  installs `nvidia-container-toolkit` and configures Docker to use it.
- **Flatpak:** adds the **Flathub** remote system-wide.
- **Browser:** makes **Helium** the default (`/etc/xdg/mimeapps.list`,
  `BROWSER`).
- **Firewall:** KDE Connect ports are opened by CachyOS's standard ufw step.

The **"Zsh plugins" page** lists about 30 built-in oh-my-zsh plugins, with
16 ticked by default: git, sudo, history-substring-search,
command-not-found, fzf, extract, colored-man-pages, copypath, copyfile,
copybuffer, dirhistory, archlinux, systemd, docker, docker-compose and
aliases. The others, such as z, web-search, ssh-agent, gh, kubectl and
vi-mode, are optional. Clicking an item toggles it. The fork's package
chooser was patched for this: multi-select pages toggle on click and
`default` accepts a list.

Everything else is unchanged: kernels, bootloader choice, chwd driver
detection, btrfs layout and snapshot, Plymouth, ufw, and the CachyOS repos and
mirrors.

The live ISO does **not** carry CUDA, the Proton VPN/Mail apps, the office
suites or the gaming packages. Those are installed only onto the target
system.

## Building

### Windows (CachyOS WSL)

```powershell
git clone --recurse-submodules https://github.com/mrquantumoff/qdrnt-linux
cd qdrnt-linux
.\scripts\wsl-build.ps1        # ISO + checksums in .\out
```

This runs `scripts/wsl-build.sh` as root in the `cachyos` WSL distro. The
script copies the repo onto the Linux filesystem, restoring file modes and
symlinks that the Windows checkout loses. It then builds `qdrnt-calamares` into
`localrepo/`, runs `buildiso.sh -p desktop`, and copies the results back to
`out/`.

To build in a clean `cachyos/cachyos` container instead of on the WSL system
itself (the same path CI uses), set `QDRNT_DOCKER=1`:

```sh
sudo QDRNT_DOCKER=1 scripts/wsl-build.sh
```

### Arch / CachyOS host

```sh
sudo pacman -S --needed archiso mkinitcpio-archiso squashfs-tools grub git rsync base-devel
git submodule update --init
sudo scripts/build-packages.sh
sudo ./buildiso.sh -p desktop
```

The installer package is always compiled for generic `x86-64`, even if the
host's `makepkg.conf` uses `-march=native`.

## Releases

`.github/workflows/monthly-iso.yml` runs at 04:00 UTC on the 1st of each month,
and can also be started manually from the Actions tab. GitHub limits release
assets to 2 GiB, so the ISO is uploaded in parts. Rebuild it with:

```sh
name=qdrnt-desktop-linux-YYMMDD.iso   # the name from the release
cat "$name".part* > "$name"
sha256sum -c "$name".sha256
```

## Layout

| Path | Purpose |
|---|---|
| `archiso/` | Live ISO profile (package list, airootfs overlay, boot configs) |
| `calamares/` | Installer fork (submodule, branch `qdrnt`) |
| `pkgbuilds/qdrnt-calamares/` | Builds the installer from the submodule working tree |
| `scripts/` | `build-packages.sh`, `wsl-build.{sh,ps1}`, `ci-build.sh` |
| `PLAN.md` | Design notes, upstream sync procedure, ideas |

## Credits

Based on the work of the [CachyOS](https://cachyos.org) team. qdrnt is not
affiliated with or endorsed by CachyOS.
