---
name: feature-checkpoint
description: Cierre de una feature en RPG-G: verificar tests, limpieza de basura, actualizar design/Feature_Checklist.md y preparar commit Conventional Commits. Usar cuando el usuario dé una feature por terminada o pida registrar un checkpoint.
---

# Skill: Cierre de Feature / Checkpoint (RPG-G)

## Pasos
1. **Verificación:** ejecutar runners relevantes (skill `godot-headless-test`). Si fallan, reportar y **no** continuar.
2. **Higiene:**
   ```bash
   git status --porcelain
   find . -path ./.git -prune -o -path ./DialogueApp/node_modules -prune -o \( -name '*~' -o -name '*.swp' -o -name '*.swo' -o -name '*.bak' -o -name '*.tmp' -o -name '.*-autosave.*' \) -print
   ```
   - Archivos nuevos en `rpg-g/` con mayúsculas en el nombre → renombrar (actualizando referencias `res://` y `.uid`).
   - Sin carpetas duplicadas ni scripts redundantes; scripts auxiliares solo en `rpg-g/tools/asset_tools/`.
   - Todo `.gd` nuevo debe tener su `.gd.uid` generado por Godot (no crearlos a mano).
3. **Checklist:** en `design/Feature_Checklist.md` marcar `[x]` lo completado con `(Referencia: archivo.gd)`. Si el usuario pide checkpoint, añadir entrada `### 🔖 Checkpoint — <día> de <Mes>, <año>: *<título>*` en "Registro de Checkpoints", siguiendo el formato de entradas previas.
4. **Commit:** mostrar el diff resumido y proponer mensaje en español, Conventional Commits (`feat(scope): ...`, `fix(scope): ...`, `docs: ...`). Separar código y docs en commits distintos si el cambio es grande. **Hacer commit solo con aprobación del usuario; push solo si lo pide.**
