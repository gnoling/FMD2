#!/usr/bin/env bash
#
# Build pb.so (lua-protobuf) for the Linux build of FMD2 and put it next to
# the binary in bin/x86_64-linux/. MangaPlus needs it ("require 'pb'"); the
# Windows release ships the same library as pb.dll (see dist/readme.md for
# the pinned commit). FMD adds its own directory to Lua's package.cpath, so
# the module is found there whatever the working directory.
#
# Needs: curl, gcc, liblua5.4-dev.
#
set -euo pipefail

COMMIT=75e3b51b8e8dda0343c9b4956e0c33b6eef44aa6
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO/bin/x86_64-linux"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src" "$DEST"
curl -fsSL -o "$WORK/luapb.tar.gz" \
  "https://codeload.github.com/starwing/lua-protobuf/tar.gz/$COMMIT"
tar -xzf "$WORK/luapb.tar.gz" -C "$WORK/src" --strip-components=1

# No -llua: the symbols come from the liblua5.4 that fmd itself has loaded.
gcc -O2 -fPIC -shared -I/usr/include/lua5.4 -o "$DEST/pb.so" "$WORK/src/pb.c"

echo "built $DEST/pb.so (lua-protobuf $COMMIT)"
