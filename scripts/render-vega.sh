#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <spec.json> <output.(png|jpg|jpeg)>" >&2
  exit 1
fi

SPEC="$1"
OUT="$2"
ext="${OUT##*.}"

if [ ! -f "$SPEC" ]; then
  echo "Spec file not found: $SPEC" >&2
  exit 1
fi

case "$ext" in
  png)
    docker run --rm \
      -v "$(pwd)":/work \
      -w /work \
      vega-cli \
      vl2png "$SPEC" --output "$OUT"
    ;;
  jpg|jpeg)
    dir="$(dirname "$OUT")"
    prefix="${dir%/}/tmp-vega-XXXXXX.png"
    tmp=$(mktemp "$prefix")
    docker run --rm \
      -v "$(pwd)":/work \
      -w /work \
      vega-cli \
      vl2png "$SPEC" --output "$tmp"
    if command -v magick >/dev/null 2>&1; then
      magick "$tmp" "$OUT"
    elif command -v convert >/dev/null 2>&1; then
      convert "$tmp" "$OUT"
    else
      echo "ImageMagick not found (magick/convert)." >&2
      rm -f "$tmp"
      exit 1
    fi
    rm -f "$tmp"
    ;;
  *)
    echo "Output must end with .png, .jpg, or .jpeg" >&2
    exit 1
    ;;
 esac
