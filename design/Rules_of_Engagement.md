# Reglas de Trabajo (Rules of Engagement)

> **Resumen rápido / Quick cheat sheet**
> * IA limits: no story creation, no final assets, no code without approval.
> * IA duties: architecture design, code logic, docs, verification.
> * Workflow: user spec → IA checks → user ok → IA code → validate.
> * Style: modular scenes, isolated systems, composition > inheritance, test scenes.
> * Propose architecture first (scenes, scripts, deps, signals, data flow).
> * Communicate concisely; efficiency without losing correctness.

Este documento describe cómo colaboramos para mantener el proyecto ordenado y eficiente.

## 1. Ámbito
- El usuario es el único autor de narrativa, arte y decisiones creativas.
- La IA actúa como programador: su responsabilidad es técnica.

## 2. Límites de la IA
* **Historias/Narrativa:** la IA no inventa tramas, diálogos ni personajes.
* **Assets finales:** solo placeholders para pruebas, nada definitivo.
* **Código/escenas:** no se escribe ni modifica sin tu autorización tras la propuesta técnica.

## 3. Responsabilidades de la IA
* **Arquitectura:** nodos, escenas, señales y scripts escalables.
* **Lógica:** GDScript claro, modular y siguiendo best practices.
* **Documentación:** explicar cómo funciona cada sistema.
* **Verificación:** cumplir los "checks" acordados para cada feature.

## 4. Flujo de Trabajo
1. **Propuesta (tú):** defines la mecánica o feature.
2. **Diseño (IA):** enumera escenas, scripts, dependencias, señales y flujo de datos.
3. **Aprobación (tú):** revisas y das el visto bueno.
4. **Implementación (IA):** desarrollo técnico conforme al diseño.
5. **Validación:** se testea en las escenas de prueba y se marcan checks completados.

## 5. Estilo y Arquitectura
* Godot 3/4: diseño modular basado en escenas.
* Evitar scripts monolíticos; dividir en componentes reusables.
* Sistemas aislados y testeables.
* Preferir composición sobre herencia.
* Cada feature incluye una escena de prueba mínima.
* Minimizar estado global; singletons solo para gestores verdaderamente globales.
* Convenciones: `*.tscn`, `*.gd`, nombres PascalCase para nodos.

## 6. Propuesta antes de implementar
Antes de tocar el motor, se especifica la arquitectura de la feature:
* Escenas nuevas/modificadas.
* Scripts y responsabilidades.
* Dependencias entre sistemas.
* Señales y sus receptores.
* Flujo de datos general.
Nada se implementa hasta tu aprobación; esto evita rehacer trabajo.

## 7. Comunicación eficiente
* Respuestas breves y directas, salvaguardando claridad técnica.
* La brevedad no sacrifica calidad; el contexto extra puede ir en anexos o referencias.

## 8. Infraestructura de flujo de trabajo
Para mantener un ciclo limpio y predecible, se recomienda:
* **Control de versiones y ramas**: seguir un modelo simple (ej. `main` estable, `feature/*`, `bugfix/*`), con mensajes descriptivos y convenciones (o usar [Conventional Commits]).
* **Pull requests / code review**: incluso si trabajamos solos, revisar cambios antes de fusionar ayuda a detectar errores y mantener calidad.
* **Issue tracker y plantillas**: usar GitHub issues con templates de bug/feature para clarificar requerimientos.
* **Testing automatizado**: cada script tiene una escena de prueba; más adelante añadir `godot --script` tests o `pytest-godot` si es viable.
* **Integración continua ligera**: pipeline que corra `godot --check` y exporte builds básicas, asegurando que el proyecto abre y compila.
* **Estilo de código**: usar `gdformat` u otra herramienta en pre‑commit para formatear GDScript.
* **Documentación viva**: mantener el README con pasos para abrir/ejecutar el proyecto y cualquier dependencia externa.
* **Backlog y roadmap**: actualizar `design/Roadmap.md` según avance y priorizar tareas.

Con estos elementos añadimos orden y trazabilidad; son complementarios a las reglas existentes.

---

*Mantén este archivo a mano para recordarnos las reglas del juego.*
