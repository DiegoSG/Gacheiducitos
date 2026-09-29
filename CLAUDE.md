@AGENTS.md

# Notas para Claude Code
- Las skills del proyecto viven en `.agents/skills/` (compartidas con otros agentes) y se exponen a Claude Code vía el symlink `.claude/skills`.
- Antes de proponer o implementar, usar las skills `project-rules` y `godot-architecture-proposal`.
- Proyecto Godot: `rpg-g/` (contiene `project.godot`). Documentación de diseño: `design/` (checklist en `design/Feature_Checklist.md`).
- Idioma de trabajo: español. Commits en formato Conventional Commits (`feat(scope): ...`, `fix(...)`, `docs: ...`).
- Subagentes en `.claude/agents/`: `godot-reviewer` (revisión de diff antes de commit) y `scene-auditor` (integridad de rutas/IDs, solo lectura).
- Hook `.claude/hooks/hygiene_check.sh` (PostToolUse) bloquea archivos basura, nombres con mayúsculas en `rpg-g/` y scripts dentro de `assets/`.
- Pruebas: skill `godot-headless-test` (requiere `$GODOT` o `godot` en PATH).
