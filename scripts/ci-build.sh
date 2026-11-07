#!/bin/bash
# Build the qdrnt ISO in a privileged CachyOS container (used by GitHub Actions):
#   docker run --rm --privileged -v "$PWD:/src" -w /src cachyos/cachyos:latest bash scripts/ci-build.sh
# The repo must be a real git checkout (modes and symlinks intact) with submodules.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
[[ -f calamares/CMakeLists.txt ]] || { echo "calamares submodule missing" >&2; exit 1; }

pacman-key --init
pacman-key --populate archlinux cachyos
pacman -Syu --noconfirm --needed archiso mkinitcpio-archiso squashfs-tools grub git rsync base-devel sudo

export USER=root
scripts/build-packages.sh
./buildiso.sh -p desktop "$@"
