#!/usr/bin/env bash
# Unpack_traces.sh : reassemble every  X.xz.p1 X.xz.p2 ...  back into X.xz, verify X.xz.sha256
# run from repo root.
#   Unpack_traces.sh              reassemble, keep parts
#   Unpack_traces.sh --rm-parts   remove parts + .sha256 after successful verify
#   Unpack_traces.sh --dry-run    reassemble into /tmp, verify hash, delete; touches nothing
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
DRY=0; RM=0
while [ $# -gt 0 ]; do case "$1" in
  --dry-run) DRY=1;;  --rm-parts) RM=1;;
  *) echo "bad arg: $1" >&2; exit 2;; esac; shift; done
TMP=/tmp/claude-unpackdry.$$; [ $DRY = 1 ] && mkdir -p "$TMP"
OK=0; BAD=0
mapfile -t FIRST < <(find "$ROOT" -type f -name '*.xz.p1' -not -path '*/.git/*' | sort)
echo "traces=${#FIRST[@]} dry=$DRY rm_parts=$RM"
for p1 in "${FIRST[@]}"; do
  stem=${p1%.p1}; name=${stem##*/}; dir=${stem%/*}
  out=$stem; [ $DRY = 1 ] && out="$TMP/$name"
  cat $(ls "$stem".p* | sort -V) > "$out"
  if [ -f "$stem.sha256" ]; then
    if (cd "${out%/*}" && sha256sum -c --quiet "$stem.sha256"); then
      echo "OK   $name  $(stat -c %s "$out") B"; OK=$((OK+1))
      [ $RM = 1 ] && [ $DRY = 0 ] && rm -f "$stem".p* "$stem.sha256"
    else
      echo "HASH-FAIL $name" >&2; BAD=$((BAD+1))
    fi
  else
    echo "NOHASH $name  $(stat -c %s "$out") B (unverified)"; OK=$((OK+1))
  fi
  [ $DRY = 1 ] && rm -f "$out"
done
[ $DRY = 1 ] && rmdir "$TMP"
echo "SUMMARY ok=$OK fail=$BAD dry=$DRY"
[ $BAD = 0 ]
