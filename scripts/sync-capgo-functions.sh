#!/bin/sh
set -e

SRC="capgo/supabase/functions"
DST="volumes/functions"
# upstream Supabase files tracked in git (.env is a dotfile, so `*` never removes it)
KEEP="main hello deno.jsonc"

mkdir -p "$DST"

# temporarily move kept entries out of the way
TMP_DIR="$(mktemp -d)"
for k in $KEEP; do
  if [ -e "$DST/$k" ]; then
    mv "$DST/$k" "$TMP_DIR/$k"
  fi
done

# clear destination
rm -rf "$DST"/*
mkdir -p "$DST"

# restore kept entries
for k in $KEEP; do
  if [ -e "$TMP_DIR/$k" ]; then
    mv "$TMP_DIR/$k" "$DST/$k"
  fi
done
rmdir "$TMP_DIR" 2>/dev/null || true

# copy functions
cp -R "$SRC"/* "$DST"/
# copy .env.example if present
if [ -f "$SRC/.env.example" ]; then
  cp "$SRC/.env.example" "$DST"/
fi

echo "✅ Done: copied functions to $DST (kept: $KEEP)"

echo "➡️  Required restart edge-functions\n"
echo "ℹ️  Look, maybe env.example has changed ?"
