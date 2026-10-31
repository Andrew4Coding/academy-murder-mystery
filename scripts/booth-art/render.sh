#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 generate.py > /dev/null
out="${1:-../../Shared/Resources/BoothArt}"
tmp="$(mktemp -d)"
xcrun --sdk macosx swiftc -o "$tmp/render" render.swift
"$tmp/render" "$PWD" "$tmp/jpg" > /dev/null
mkdir -p "$out"
for f in "$tmp"/jpg/*.jpg; do
  sips -z 900 1600 -s format jpeg -s formatOptions 82 "$f" --out "$out/$(basename "$f")" > /dev/null
done
rm -rf "$tmp"

python3 - "$out" "$PWD/../../cloud/src/host/booth-art.ts" <<'PY'
import base64, pathlib, sys
src, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
lines = ["export const boothArt: Record<string, string> = {"]
for f in sorted(src.glob("*.jpg")):
    lines.append(f'  "{f.stem}": "{base64.b64encode(f.read_bytes()).decode()}",')
lines.append("};")
dest.write_text("\n".join(lines) + "\n")
PY
