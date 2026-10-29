#!/usr/bin/env bash
# pack_traces.sh : split every .xz into parts  X.xz.p1 X.xz.p2 ...  each < 50MB, plus X.xz.sha256
# run from repo root.
#   pack_traces.sh                      in-place: find *.xz under repo, split beside, verify, remove original
#   pack_traces.sh --src DIR --dest SUB  split DIR/*.xz into repo SUB/ (source untouched)
#   pack_traces.sh --dry-run [...]       split into /tmp, reassemble, cmp vs original, report, delete tmp; touches nothing
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
PART=49M                       # 49*2^20 = 51380224 B < GitHub 50 MiB warn / 100 MiB block
DRY=0; SRC=""; DEST=""
while [ $# -gt 0 ]; do case "$1" in
  --dry-run) DRY=1;;  --src) SRC=$2; shift;;  --dest) DEST=$2; shift;;
  *) echo "bad arg: $1" >&2; exit 2;; esac; shift; done
if [ -n "$SRC" ] && [ -z "$DEST" ]; then echo "--src needs --dest" >&2; exit 2; fi
TMP=/tmp/claude-packdry.$$; [ $DRY = 1 ] && mkdir -p "$TMP"
PBYTES=$((49*1024*1024)); OK=0; BAD=0; NPART=0

pack_one() {                   # $1 = source .xz path, $2 = dir where parts go
  local src=$1 outdir=$2 name size n a out stem
  name=${src##*/}; size=$(stat -c %s "$src"); n=$(( (size + PBYTES - 1) / PBYTES )); a=${#n}
  stem="$outdir/$name"
  split -b "$PART" --numeric-suffixes=1 -a "$a" "$src" "$stem.p"
  for p in "$stem".p*; do s=${p##*.p}; t=$((10#$s)); [ "$s" != "$t" ] && mv "$p" "$stem.p$t"; done   # p01 -> p1
  # verify: reassemble parts in order, compare byte-exact to source, hash on the fly
  if cat $(ls "$stem".p* | sort -V) | tee >(sha256sum | awk -v f="$name" '{print $1"  "f}' > "$stem.sha256") | cmp -s - "$src"; then
    echo "OK   $name  $size B  $n parts"; OK=$((OK+1)); NPART=$((NPART+n))
  else
    echo "DIFF $name  $size B  $n parts" >&2; BAD=$((BAD+1))
  fi
}

if [ -n "$SRC" ]; then
  mapfile -t FILES < <(find "$SRC" -maxdepth 1 -type f -name '*.xz' | sort)
else
  mapfile -t FILES < <(find "$ROOT" -type f -name '*.xz' -not -path '*/.git/*' | sort)
fi
echo "files=${#FILES[@]} part=$PART dry=$DRY"
for f in "${FILES[@]}"; do
  if [ $DRY = 1 ]; then
    pack_one "$f" "$TMP"; rm -f "$TMP"/*
  elif [ -n "$SRC" ]; then
    mkdir -p "$ROOT/$DEST"; pack_one "$f" "$ROOT/$DEST"
  else
    pack_one "$f" "${f%/*}"
    [ -s "${f}.sha256" ] && rm -f "$f"       # original gone only after verified parts + hash exist
  fi
done
[ $DRY = 1 ] && rmdir "$TMP"
echo "SUMMARY ok=$OK diff=$BAD parts=$NPART dry=$DRY"
[ $BAD = 0 ]
