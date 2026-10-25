---
name: godot-headless-test
description: Ejecuta los test runners headless (src/core/tests/*_runner.gd) y escenas test_*.tscn de RPG-G con Godot 4.6 y resume resultados PASS/FAIL. Usar en el paso de Verificación del flujo de trabajo.
---

# Skill: Ejecución de Pruebas Headless (RPG-G)

## 1. Binario de Godot
- Usar `$GODOT` si está definida; si no, `godot` del PATH. Si no existe ninguno, **detenerse y pedir al usuario la ruta** (no inventarla).
- Raíz del proyecto: `rpg-g/` (contiene `project.godot`).
- Si es la primera ejecución o hay recursos nuevos, importar antes: `$GODOT --headless --path rpg-g --import`.

> **Estado actual (2026-09-29):** los runners existentes NO compilan en modo `--script` (referencian autoloads por nombre y se compilan antes de que existan). El usuario decidió dejarlos así: el QA lo hace él manualmente en Godot. Usar esta skill solo si el usuario lo pide; por defecto, en la fase de Verificación entregar pasos concretos de prueba manual.

## 2. Runners automatizados (`extends SceneTree`)
Ubicados en `rpg-g/src/core/tests/`. Cada runner imprime `[PASS]`/`[FAIL]` y termina con `quit(0)` (éxito) o `quit(1)`.

```bash
# Uno
timeout 120 $GODOT --headless --path rpg-g --script res://src/core/tests/test_death_and_respawn_runner.gd
# Todos
for f in rpg-g/src/core/tests/*_runner.gd; do
  echo "=== $f"; timeout 120 $GODOT --headless --path rpg-g --script "res://${f#rpg-g/}"; echo "exit=$?"
done
```
- Siempre usar `timeout`: un runner que olvida `quit()` se queda colgado.
- Los autoloads de `project.godot` están disponibles en `root` tras `await process_frame`.

## 3. Escenas de prueba (`test_*.tscn`)
- Arranque de humo (detecta errores de carga/scripts): `timeout 15 $GODOT --headless --path rpg-g res://ruta/test_x.tscn --quit-after 300`.
- Buscar en la salida `SCRIPT ERROR`, `ERROR:`, `Parse Error`, `Failed to load`.
- La validación visual/interactiva la hace el usuario: indicarle qué probar manualmente.

## 4. Reporte
Resumir: runners ejecutados, conteo PASS/FAIL, código de salida y los errores exactos (archivo:línea). Nunca declarar éxito si hubo `FAIL`, `SCRIPT ERROR` o timeout.

## 5. Nuevos runners
- Nombre `test_<feature>_runner.gd` en `src/core/tests/`, `extends SceneTree`, contadores `_passed_count`/`_failed_count`, terminar con `quit(0 if _failed_count == 0 else 1)`.

## 6. Chequeo de compilación que SÍ funciona
Un script `extends SceneTree` que espera 2 `process_frame` y luego hace `ResourceLoader.load(ruta, "", CACHE_MODE_IGNORE)` de cada .gd/.tscn/.tres (comprobando `GDScript.can_instantiate()`) detecta errores de compilación con los autoloads ya activos. Los scripts de prueba no deben nombrar autoloads como identificadores: usar `root.get_node("Inventory")`. Tras crear un `class_name` nuevo, ejecutar antes `--import` para que Godot lo registre.
