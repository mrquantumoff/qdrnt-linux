#!/bin/bash
# Build the packages in pkgbuilds/ and publish them as the build-time
# [qdrnt-local] pacman repo in ./localrepo (consumed by archiso/pacman.conf).
#
# Run as root on an Arch/CachyOS host. makepkg itself runs as an unprivileged
# build user ($QDRNT_BUILD_USER, default: qdrnt-build, created if missing).
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
localrepo="${src_dir}/localrepo"
build_user="${QDRNT_BUILD_USER:-qdrnt-build}"

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

if ! id "$build_user" &>/dev/null; then
    useradd --system --create-home --home-dir "/var/lib/${build_user}" "$build_user"
fi

workdir="$(mktemp -d /var/tmp/qdrnt-pkgbuild.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT
chown "$build_user": "$workdir"

# The ISO must run on any x86-64 CPU: never inherit the host's -march=native/-v3/-v4 flags.
makepkg_conf="$workdir/makepkg.conf"
{
    cat /etc/makepkg.conf
    cat <<'EOF'

# qdrnt: portable flags for packages shipped on the ISO
CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
RUSTFLAGS="-C opt-level=2"
EOF
} > "$makepkg_conf"
chmod 644 "$makepkg_conf"

mkdir -p "$localrepo"
rm -f "$localrepo"/*.pkg.tar.zst "$localrepo"/qdrnt-local.*

for pkgdir in "$src_dir"/pkgbuilds/*/; do
    name="$(basename "$pkgdir")"
    echo "==> building $name"

    # Install build dependencies as root (makepkg -s would need sudo for the build user).
    mapfile -t deps < <(
        startdir="$pkgdir"
        # shellcheck disable=SC1091
        source "$pkgdir/PKGBUILD"
        printf '%s\n' "${depends[@]}" "${makedepends[@]}"
    )
    pacman -S --noconfirm --needed "${deps[@]}"

    build="$workdir/$name"
    cp -r "$pkgdir" "$build"
    chown -R "$build_user": "$build"

    # Sources outside the build dir (e.g. the calamares submodule) are passed in explicitly.
    runuser -u "$build_user" -- env \
        QDRNT_CALAMARES_SRC="$src_dir/calamares" \
        PKGDEST="$build/out" \
        bash -c "cd '$build' && makepkg --config '$makepkg_conf' --noconfirm --cleanbuild --force"

    cp "$build"/out/*.pkg.tar.zst "$localrepo/"
done

repo-add "$localrepo/qdrnt-local.db.tar.gz" "$localrepo"/*.pkg.tar.zst
echo "==> local repo ready: $localrepo"
