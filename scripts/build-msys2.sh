#!/usr/bin/env bash
# build-msys2.sh - build darkzilla (FileZilla Client + dark mode) for Windows.
#
# Runs inside an MSYS2 MINGW64 shell (GitHub Actions windows-latest via
# msys2/setup-msys2, or a local MSYS2 install).
#
#   usage: build-msys2.sh <filezilla-version>
#
# Dependency build order follows the verified recipe from
# Pharaoh2k/FileZilla-Themed-For-Windows (BUILD.md):
#   pacman deps -> libfilezilla -> fzssh -> wxWidgets 3.3 (patched) -> filezilla
#
# Output: darkzilla-<ver>-win64.zip in $WORK/dist.
set -euo pipefail

FZVER="${1:?usage: build-msys2.sh <filezilla-version>}"
WXVER="${WXVER:-3.3.3}"
LIBFZVER="${LIBFZVER:-0.57.0}"
FZSSHVER="${FZSSHVER:-1.4.0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # darkzilla repo root
WORK="${WORK:-$PWD/work}"
PREFIX="$WORK/prefix"                            # dep install prefix
WXPREFIX="$WORK/wx33"                            # wxWidgets 3.3 prefix (separate, so it can't clash)
DIST="$WORK/dist"

mkdir -p "$WORK" "$PREFIX/bin" "$PREFIX/lib/pkgconfig" "$PREFIX/include" "$DIST"
export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CPPFLAGS="-I$PREFIX/include ${CPPFLAGS:-}"
export LDFLAGS="-L$PREFIX/lib ${LDFLAGS:-}"

NPROC="$(nproc 2>/dev/null || echo 4)"
MAKE=mingw32-make

fetch() { # url dest
    echo ">> fetch $1"
    curl -fL --retry 3 --connect-timeout 30 -o "$2" "$1"
}

say() { printf '\n==== %s ====\n' "$*"; }

# MSYS2 quirk: upstream locales Makefiles fix the .pot Content-Type header
# with a sed whose replacement contains \\n. The shell collapses it to \n,
# GNU sed emits a raw newline, and the resulting catalog is corrupt
# ("end-of-line within string"), which makes every msgmerge call fail.
# One extra backslash level makes sed emit a literal \n as intended.
fix_locale_makefile() {
    [ -f locales/Makefile ] || return 0
    sed -i '/Content-Type: text/s/\\\\n/\\\\\\\\n/g' locales/Makefile
}

# ---------------------------------------------------------------- libfilezilla
if [ -f "$PREFIX/lib/libfilezilla.dll.a" ]; then
    say "libfilezilla $LIBFZVER (cached)"
else
say "libfilezilla $LIBFZVER"
cd "$WORK"
fetch "https://deb.debian.org/debian/pool/main/libf/libfilezilla/libfilezilla_${LIBFZVER}.orig.tar.xz" libfilezilla.tar.xz
rm -rf libfilezilla-src && mkdir libfilezilla-src
tar -xf libfilezilla.tar.xz -C libfilezilla-src --strip-components=1
cd libfilezilla-src
./configure --prefix="$PREFIX" --disable-static MAKE=$MAKE
fix_locale_makefile
$MAKE -C lib -j"$NPROC"
# `make install` is unreliable under msys; install the artifacts manually.
cp -f lib/.libs/libfilezilla-*.dll "$PREFIX/bin/"
cp -f lib/.libs/libfilezilla.dll.a "$PREFIX/lib/"
cp -f lib/.libs/libfilezilla.la "$PREFIX/lib/" 2>/dev/null || true
cp -rf lib/libfilezilla "$PREFIX/include/"
cp -f lib/libfilezilla.pc "$PREFIX/lib/pkgconfig/"
# Translations are nice-to-have; with the Makefile fix they build, but
# don't let a catalog hiccup kill the build.
if ($MAKE -C locales -j"$NPROC") 2>/dev/null; then
    for mo in locales/*.mo; do
        [ -f "$mo" ] || continue
        lang="$(basename "$mo" .mo)"
        mkdir -p "$PREFIX/share/locale/$lang/LC_MESSAGES"
        cp "$mo" "$PREFIX/share/locale/$lang/LC_MESSAGES/libfilezilla.mo"
    done
fi
fi

# ---------------------------------------------------------------- fzssh
if compgen -G "$PREFIX/lib/pkgconfig/fzssh*.pc" > /dev/null \
   || compgen -G "$PREFIX/lib/libfzssh-client*" > /dev/null; then
    say "fzssh $FZSSHVER (cached)"
else
say "fzssh $FZSSHVER"
cd "$WORK"
fetch "https://deb.debian.org/debian/pool/main/f/fzssh/fzssh_${FZSSHVER}.orig.tar.xz" fzssh.tar.xz
rm -rf fzssh-src && mkdir fzssh-src
tar -xf fzssh.tar.xz -C fzssh-src --strip-components=1
cd fzssh-src
meson setup build --prefix="$PREFIX" --buildtype=release
meson compile -C build
meson install -C build
fi

# ---------------------------------------------------------------- wxWidgets
if [ -f "$WXPREFIX/bin/wx-config" ]; then
    say "wxWidgets $WXVER (cached)"
else
say "wxWidgets $WXVER (patched)"
cd "$WORK"
fetch "https://github.com/wxWidgets/wxWidgets/releases/download/v${WXVER}/wxWidgets-${WXVER}.tar.bz2" wx.tar.bz2
rm -rf wx-src && mkdir wx-src
tar -xf wx.tar.bz2 -C wx-src --strip-components=1
cd wx-src
# Route WM_DRAWITEM by control HWND, not id: FileZilla reuses one id for many
# owner-drawn controls, so stock wx leaves dark-mode checkboxes unpainted.
patch -p1 < "$ROOT/patches/wxwidgets/wx333-darkmode-ownerdrawn-fixes.patch"
mkdir -p build-msw && cd build-msw
../configure --prefix="$WXPREFIX" \
    --enable-printfposparam --with-msw --disable-tests --without-opengl \
    --enable-shared MAKE=$MAKE CXXFLAGS="-O2 -pipe"
$MAKE -j"$NPROC"
$MAKE install || true   # header install partially fails under msys; finish below
mkdir -p "$WXPREFIX/include/wx-3.3" "$WXPREFIX/lib" "$WXPREFIX/bin"
cp -rf ../include/wx "$WXPREFIX/include/wx-3.3/" 2>/dev/null || true
cp -f lib/*.dll "$WXPREFIX/lib/" 2>/dev/null || true
# make install can die on the giant header-install loop before installing
# wx-config; configure already generated a usable copy in the build dir.
if [ ! -f "$WXPREFIX/bin/wx-config" ]; then
    cp -f wx-config "$WXPREFIX/bin/" && chmod +x "$WXPREFIX/bin/wx-config"
fi
fi

# wx-config wrapper that pins the 3.3 prefix (avoids /mingw64 ambiguity).
mkdir -p "$WORK/bin"
cat > "$WORK/bin/wx-config" <<EOF
#!/bin/sh
exec "$WXPREFIX/bin/wx-config" --prefix="$WXPREFIX" --exec-prefix="$WXPREFIX" "\$@"
EOF
chmod +x "$WORK/bin/wx-config"

# ---------------------------------------------------------------- filezilla
say "FileZilla $FZVER (patched)"
cd "$WORK"
fetch "https://deb.debian.org/debian/pool/main/f/filezilla/filezilla_${FZVER}.orig.tar.xz" filezilla.tar.xz
rm -rf filezilla-src && mkdir filezilla-src
tar -xf filezilla.tar.xz -C filezilla-src --strip-components=1
cd filezilla-src

for p in "$ROOT"/patches/filezilla/*.patch; do
    echo ">> apply $(basename "$p")"
    patch -p1 < "$p"
done

# 0001 patches configure.ac, which makes automake's maintainer rules want
# to regen aclocal.m4/Makefile.in (aclocal-1.17 isn't installed). We ship
# the matching generated 'configure' already patched, so just make all
# autotools outputs look newer than their inputs.
echo ">> refresh autotools timestamps"
touch aclocal.m4 configure
[ -f config/config.h.in ] && touch config/config.h.in
find . -name 'Makefile.in' -exec touch {} +

mkdir -p compile && cd compile
../configure --prefix="$PREFIX" --disable-static \
    --disable-manualupdatecheck --disable-dependency-tracking \
    MAKE=$MAKE \
    --with-wx-config="$WORK/bin/wx-config" \
    --with-pugixml=builtin
fix_locale_makefile
# Drop the fzshellext subdirs from the build: its nested configure runs
# with an absolute /d/... srcdir that mingw32-make cannot stat, and the
# 32-bit variant would need the i686 toolchain we don't install. This
# only costs the Explorer context-menu shell extension.
sed -i '/^ *MAYBE_FZSHELLEXT =/s|=.*|=|' src/Makefile
$MAKE -j"$NPROC" CXXFLAGS="-g -O2 -pipe" CFLAGS="-g -O2 -pipe"

# Translation catalogs (out-of-tree build can't find the shipped .pot).
(cd locales && cp -f ../../locales/filezilla.pot ./filezilla.pot && $MAKE -j"$NPROC" allmo) || true

$MAKE install || $MAKE -C src/interface install

# ---------------------------------------------------------------- package
say "package"
ZIPROOT="$WORK/pkg/FileZilla-${FZVER}-dark"
rm -rf "$WORK/pkg" && mkdir -p "$ZIPROOT"

cp -f "$PREFIX/bin/filezilla.exe" "$ZIPROOT/" 2>/dev/null \
    || cp -f src/interface/filezilla.exe "$ZIPROOT/" 2>/dev/null \
    || cp -f src/interface/.libs/filezilla.exe "$ZIPROOT/"

# Runtime DLLs: walk ldd closure of filezilla.exe, skipping Windows system dirs.
collect() {
    local bin="$1"
    ldd "$bin" 2>/dev/null | awk '/=>/ && $3 ~ /^\// {print $3}' | while read -r d; do
        case "$d" in
            /c/Windows/*|/c/WINDOWS/*|/cygdrive/c/Windows/*|/cygdrive/c/WINDOWS/*) continue ;;
        esac
        [ -f "$d" ] || continue
        local base; base="$(basename "$d")"
        if [ ! -f "$ZIPROOT/$base" ]; then
            cp "$d" "$ZIPROOT/"
            collect "$ZIPROOT/$base"
        fi
    done
}
collect "$ZIPROOT/filezilla.exe"
cp -f "$WXPREFIX"/lib/*.dll "$ZIPROOT/" 2>/dev/null || true

# Ship release-size binaries (the build uses -g for diagnosability).
strip "$ZIPROOT/filezilla.exe" "$ZIPROOT"/*.dll 2>/dev/null || true

# Resources + locales + docs, matching upstream's makezip.sh layout.
cp -rf "$PREFIX/share/filezilla/resources" "$ZIPROOT/resources" 2>/dev/null \
    || cp -rf ../src/interface/resources "$ZIPROOT/resources"

if [ -d locales ]; then
    for mo in locales/*.mo; do
        [ -f "$mo" ] || continue
        lang="$(basename "$mo" .mo)"
        mkdir -p "$ZIPROOT/locales/$lang"
        cp "$mo" "$ZIPROOT/locales/$lang/filezilla.mo"
    done
    # libfilezilla translations
    for mo in "$PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        [ -f "$mo" ] || continue
        lang="$(basename "$(dirname "$(dirname "$mo")")")"
        mkdir -p "$ZIPROOT/locales/$lang"
        cp "$mo" "$ZIPROOT/locales/$lang/libfilezilla.mo"
    done
fi

mkdir -p "$ZIPROOT/docs"
cp -f ../docs/fzdefaults.xml.example "$ZIPROOT/docs/" 2>/dev/null || true
cp -f ../GPL.html ../AUTHORS ../NEWS "$ZIPROOT/" 2>/dev/null || true
cp -f "$ROOT/install.ps1" "$ROOT/install.cmd" "$ROOT/update.cmd" "$ZIPROOT/" 2>/dev/null || true

cd "$WORK/pkg"
zip -r -9 "$DIST/darkzilla-${FZVER}-win64.zip" "$(basename "$ZIPROOT")"

say "done: $DIST/darkzilla-${FZVER}-win64.zip"
ls -la "$DIST"
