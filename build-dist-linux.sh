#!/usr/bin/env bash
#
# Assemble a self-contained Linux (x86_64/GTK2) distribution folder for FMD2.
# Produces dist/FMD2-x86_64-linux/ (a runnable app folder) and a .tar.gz of it.
#
# The binary itself is built separately (see build instructions / memory);
# this script only stages the already-built binary, the custom duktape lib,
# the runtime assets and a launcher into a clean, copy-anywhere folder.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$REPO/bin/x86_64-linux"
NAME="FMD2-x86_64-linux"
DEST="$REPO/dist/$NAME"

if [[ ! -x "$BIN/fmd" ]]; then
  echo "error: $BIN/fmd not found. Build it first (lazbuild ... md.lpi)." >&2
  exit 1
fi
if [[ ! -f "$BIN/libduktape_fmd.so" ]]; then
  echo "error: $BIN/libduktape_fmd.so not found." >&2
  exit 1
fi

echo ">> staging into $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"

# --- binary + custom library -------------------------------------------------
cp "$BIN/fmd" "$DEST/fmd"
cp "$BIN/libduktape_fmd.so" "$DEST/libduktape_fmd.so"
# the binary finds libduktape_fmd.so next to itself via an $ORIGIN runpath
patchelf --set-rpath '$ORIGIN' "$DEST/fmd"

# --- runtime assets (dereference the repo symlinks into real copies) ---------
cp -rL "$REPO/lua"       "$DEST/lua"
cp -rL "$REPO/languages" "$DEST/languages"
cp -rL "$REPO/images"    "$DEST/images"

# about-tab content (loaded from next to the binary at runtime)
cp "$REPO/readme.rtf"     "$DEST/readme.rtf"
cp "$REPO/changelog.txt"  "$DEST/changelog.txt"

# default module/website config (created/overwritten in userdata on first run)
if [[ -f "$REPO/dist/config.json" ]]; then
  cp "$REPO/dist/config.json" "$DEST/config.json"
elif [[ -f "$BIN/config.json" ]]; then
  cp "$BIN/config.json" "$DEST/config.json"
fi

# --- launcher ----------------------------------------------------------------
cat > "$DEST/fmd.sh" <<'LAUNCH'
#!/bin/sh
# Launch FMD2 from its own folder so all assets/config resolve correctly,
# regardless of the directory you start it from.
cd "$(dirname "$(readlink -f "$0")")" || exit 1
exec ./fmd "$@"
LAUNCH
chmod +x "$DEST/fmd.sh" "$DEST/fmd"

# --- readme ------------------------------------------------------------------
cp "$REPO/dist/README-linux.txt" "$DEST/README.txt" 2>/dev/null || true

# --- tarball -----------------------------------------------------------------
echo ">> creating tarball"
( cd "$REPO/dist" && tar czf "$NAME.tar.gz" "$NAME" )

echo
echo ">> done:"
du -sh "$DEST" "$REPO/dist/$NAME.tar.gz" | sed 's/^/   /'
echo "   run it with:  $DEST/fmd.sh"
