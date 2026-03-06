#!/bin/bash

BASE_DIR="$(pwd)"
OUTPUT_DIR="$BASE_DIR/processed"

mkdir -p "$OUTPUT_DIR"

find "$BASE_DIR" -type f -iname "*.png" | while read file; do

  # Ruta relativa
  rel_path="${file#$BASE_DIR/}"
  out_path="$OUTPUT_DIR/$rel_path"

  # Crear subcarpetas necesarias
  mkdir -p "$(dirname "$out_path")"

  convert "$file" \
    -filter point \
    -resize 133.333% \
    -gravity center \
    -crop 32x32+0+0 +repage \
    "$out_path"

  echo "Procesado: $rel_path"

done

echo "Listo 🚀"
