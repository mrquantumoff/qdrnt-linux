#!/bin/bash
# Build the qdrnt ISO inside the CachyOS WSL distro.
#
#   From Windows:  scripts\wsl-build.ps1
#   Inside WSL:    sudo scripts/wsl-build.sh
#
# The repo usually lives on the Windows drive (/mnt/c/...), where archiso can't
# work (no real permissions, symlinks stored as plain files). So the tree is
# copied to the Linux filesystem, permissions/symlinks are restored from the git
# index, the ISO is built there and copied back to ./out.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${QDRNT_BUILD_ROOT:-/var/tmp/qdrnt-build}"
dest="$build_root/src"

[[ $EUID -eq 0 ]] || { echo "run as root (wsl -u root, or sudo)" >&2; exit 1; }
export USER=root

if [[ "${QDRNT_DOCKER:-0}" == 1 ]]; then
    command -v docker >/dev/null || { echo "QDRNT_DOCKER=1 needs docker" >&2; exit 1; }
    command -v rsync >/dev/null || pacman -S --noconfirm --needed rsync
else
    echo "==> installing build tools"
    pacman -Syu --noconfirm --needed archiso mkinitcpio-archiso squashfs-tools grub git rsync base-devel
fi

git_src() { git -c safe.directory='*' -C "$src" "$@"; }

[[ -f "$src/calamares/CMakeLists.txt" ]] || git_src submodule update --init

echo "==> copying $src -> $dest"
mkdir -p "$dest"
rsync -a --delete --no-perms --chmod=D755,F644 \
    --exclude /build --exclude /out --exclude /localrepo --exclude .git \
    "$src/" "$dest/"

echo "==> restoring modes and symlinks from the git index"
restore_from_index() {
    local repo="$1" prefix="$2" mode path target
    git -c safe.directory='*' -C "$repo" ls-files -s | while read -r mode _ _ path; do
        case "$mode" in
            100755) chmod 755 "$dest/$prefix$path" ;;
            120000)
                target="$(cat "$dest/$prefix$path")"
                rm -f "$dest/$prefix$path"
                ln -s "$target" "$dest/$prefix$path"
                ;;
        esac
    done
}
restore_from_index "$src" ""
restore_from_index "$src/calamares" "calamares/"

cd "$dest"
if [[ "${QDRNT_DOCKER:-0}" == 1 ]]; then
    # Same path as GitHub Actions: build in a clean CachyOS container.
    echo "==> building in docker (cachyos/cachyos:latest)"
    rm -rf "$dest/build" "$dest/out" "$dest/localrepo"
    docker run --rm --privileged -v "$dest:/src" -w /src cachyos/cachyos:latest \
        bash scripts/ci-build.sh "$@"
else
    echo "==> building local packages"
    scripts/build-packages.sh

    echo "==> building ISO"
    ./buildiso.sh -p desktop "$@"
fi

mkdir -p "$src/out"
cp -v out/desktop/qdrnt-* "$src/out/"
echo "==> done: $src/out"
