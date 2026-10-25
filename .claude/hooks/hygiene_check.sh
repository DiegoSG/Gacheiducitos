#!/usr/bin/env bash
# PostToolUse (Write|Edit): avisa si se crea basura o archivos con nombre no snake_case en rpg-g/.
f=$(jq -r '.tool_input.file_path // empty')
[ -z "$f" ] && exit 0
name=$(basename "$f")
case "$name" in
  *~|*.swp|*.swo|*.bak|*.tmp|.*-autosave.*)
    echo "Higiene: '$f' es un archivo temporal prohibido por AGENTS.md. Elimínalo." >&2; exit 2;;
esac
if [[ "$f" == */rpg-g/* && "$f" != */addons/* && "$name" =~ [A-Z] ]]; then
  echo "Higiene: '$name' tiene mayúsculas; los archivos deben ser snake_case (AGENTS.md)." >&2; exit 2
fi
if [[ "$f" == */rpg-g/assets/* && "$name" =~ \.(gd|py|sh)$ ]]; then
  echo "Higiene: scripts no pueden vivir en assets/; usar rpg-g/tools/asset_tools/." >&2; exit 2
fi
exit 0
