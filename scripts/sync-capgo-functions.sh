#!/bin/sh
set -e

SRC="capgo/supabase/functions"
DST="volumes/functions"
KEEP="main"

mkdir -p "$DST"

# temporarily move main out of the way
if [ -d "$DST/$KEEP" ]; then
  TMP_DIR="$(mktemp -d)"
  mv "$DST/$KEEP" "$TMP_DIR/$KEEP"
fi

# clear destination
rm -rf "$DST"/*
mkdir -p "$DST"

# restore main
if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR/$KEEP" ]; then
  mv "$TMP_DIR/$KEEP" "$DST/$KEEP"
  rmdir "$TMP_DIR" 2>/dev/null || true
fi

# copy functions
cp -R "$SRC"/* "$DST"/
# copy .env.example if present
if [ -f "$SRC/.env.example" ]; then
  cp "$SRC/.env.example" "$DST"/
fi

echo "✅ Done: copied functions to $DST (kept $DST/$KEEP)"

echo "➡️  Required restart edge-functions\n"
echo "ℹ️  Look, maybe env.example has changed ?"