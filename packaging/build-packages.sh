#!/usr/bin/env bash
# Builds the release packages into dist/:
#   ./packaging/build-packages.sh [kwinscript] [deb] [rpm] [arch]   (all by default)
#
# kwinscript: the KWin script alone, for System Settings > KWin Scripts.
# deb:  built on this machine with CPack (Debian, Ubuntu, KDE neon, Tuxedo OS).
# rpm:  built and install-tested in a Fedora container, from the .spec file.
# arch: the PKGBUILD is built with makepkg in an Arch Linux container.
# The containers build from a tarball of the working tree, so uncommitted
# changes are included; the published PKGBUILD and .spec use the GitHub tag.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
dist="$here/dist"
name=osd-desk-snake
version=$(sed -n 's/^project(osd-desk-snake VERSION \([0-9.]*\).*/\1/p' "$here/CMakeLists.txt")
fedora=fedora:44
targets=("${@:-kwinscript deb rpm arch}")
targets=(${targets[*]})

mkdir -p "$dist"

source_tarball() {
    local tarball="$dist/$name-$version.tar.gz"
    tar -C "$here" --transform "s,^\.,$name-$version," \
        --exclude=./.git --exclude='./build*' --exclude=./dist \
        --exclude=./settings-app/build --exclude=./tests/preview-out \
        --exclude=./package/contents/locale --exclude='__pycache__' \
        -czf "$tarball" .
    echo "$tarball"
}

build_kwinscript() {
    local stage po lang
    stage=$(mktemp -d)
    cp -r "$here/package/." "$stage/"
    # KWin loads the translations of the script settings page from contents/locale.
    rm -rf "$stage/contents/locale"
    for po in "$here"/po/*.po; do
        lang=$(basename "$po" .po)
        mkdir -p "$stage/contents/locale/$lang/LC_MESSAGES"
        msgfmt -o "$stage/contents/locale/$lang/LC_MESSAGES/$name.mo" "$po"
    done
    rm -f "$dist/$name-$version.kwinscript"
    (cd "$stage" && zip -qrX "$dist/$name-$version.kwinscript" .)
    # Install test into a scratch package root, as Install from File would.
    rm -rf "$stage" && mkdir "$stage"
    kpackagetool6 --type KWin/Script --packageroot "$stage" --install "$dist/$name-$version.kwinscript"
    find "$stage" -name metadata.json -o -name '*.mo' | sed "s,^$stage/,,"
    rm -rf "$stage"
}

build_deb() {
    local build="$here/build-deb"
    rm -rf "$build"
    cmake -S "$here" -B "$build" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_DEBIAN_DOCS=ON >/dev/null
    cmake --build "$build" -j"$(nproc)" >/dev/null
    (cd "$build" && cpack -G DEB >/dev/null)
    cp "$build"/*.deb "$dist/"
    lintian "$dist/${name}_${version}_amd64.deb" && echo "lintian: clean"
}

build_rpm() {
    source_tarball >/dev/null
    docker run --rm -v "$dist:/dist" -v "$here/packaging/rpm:/spec:ro" "$fedora" bash -euc "
        dnf -q -y install rpm-build 'dnf-command(builddep)' >/dev/null
        dnf -q -y builddep /spec/$name.spec >/dev/null 2>&1
        mkdir -p ~/rpmbuild/SOURCES && cp /dist/$name-$version.tar.gz ~/rpmbuild/SOURCES/
        rpmbuild --quiet -bb /spec/$name.spec
        cp ~/rpmbuild/RPMS/x86_64/$name-$version-*.rpm /dist/
        # Install test: every dependency must resolve on a stock Fedora (the container
        # image ships a trimmed systemd that must make way for the one KWin needs).
        dnf -q -y install --allowerasing /dist/$name-$version-*.x86_64.rpm >/dev/null 2>&1
        rpm -ql $name | grep -E 'bin/|metadata.json|\.mo$'
        chown $(id -u):$(id -g) /dist/*.rpm"
}

build_arch() {
    local tarball
    tarball=$(source_tarball)
    docker run --rm -v "$dist:/dist" -v "$here/packaging/arch/PKGBUILD:/PKGBUILD:ro" archlinux:latest bash -euc "
        pacman -Syu --noconfirm --needed base-devel >/dev/null 2>&1
        useradd -m builder && echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
        su builder -c 'mkdir -p ~/pkg && cp /PKGBUILD ~/pkg/ && cp /dist/$(basename "$tarball") ~/pkg/'
        # The local tarball stands for the GitHub one: checksums are skipped here.
        su builder -c 'cd ~/pkg && makepkg -s --noconfirm --skipchecksums' >/dev/null
        cp /home/builder/pkg/$name-$version-*.pkg.tar.zst /dist/
        pacman -U --noconfirm /dist/$name-$version-*.pkg.tar.zst >/dev/null
        pacman -Ql $name | grep -E 'bin/|metadata.json|\.mo$'
        chown $(id -u):$(id -g) /dist/*.pkg.tar.zst"
}

for target in "${targets[@]}"; do
    echo "== $target"
    "build_$target"
done
ls -la "$dist"
