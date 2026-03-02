# Features Checklist

Este documento contiene la lista de funcionalidades y los puntos de control (checks) que deben cumplirse antes de dar una tarea por terminada.

## 🟢 Core Engine (Completado/En proceso)
- [x] Movimiento 8 direcciones (Referencia: `player.gd`)
- [x] Cámara sin límites (Referencia: `overworld.tscn`)
- [x] Sistema de interacción base (Referencia: `actionable.gd`)
- [x] Manager de transiciones (Referencia: `game_manager.gd`)
- [x] Scripting de NPCs con misiones/diálogos básicos (básico en `NPCQuestGiver.gd`)
- [x] Inventario simple para recoger/intercambiar ítems (`Inventory.gd` + UI) – usar nombre de singleton `InventoryManager` si ya existe conflicto
- [ ] Sistema de progresión (niveles/estadísticas/items)
- [ ] Áreas desbloqueables y control de mapa

## 🟡 Feature: Minijuego A (Excavación)
*Usado como desafío de quest con rejugabilidad y puente de inventario.*
- [x] Generador Procedimental (Autómatas Celulares) (Ref: `Minijuego_Supaplex.md`)
- [x] Algoritmo de Validación de Conectividad (Flood Fill) (Ref: `Minijuego_Supaplex.md`)
- [ ] Reglas de "Riesgo vs Recompensa" (Colocación de items) (Ref: `Minijuego_Supaplex.md`)
- [ ] Perfiles de Nivel (Variación de densidades) (Ref: `Minijuego_Supaplex.md`)
- [x] Motor de Grid y Lógica de Excavación (Ref: `Minijuego_Supaplex.md`)
- [x] Gravedad de Piedras (Caída y Deslizamiento) (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Misión (Contador de Raíces / Rescate de NPC) (Ref: `Minijuego_Supaplex.md`)
- [ ] Generador de Loot (Monedas, Corazones) (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Bombas (Colocación y cuenta atrás) (Ref: `Minijuego_Supaplex.md`)
- [ ] Lógica de Explosión 3x3 (Detección de tiles destructibles) (Ref: `Minijuego_Supaplex.md`)
- [ ] Tipos de Muro (Irrompible vs Rompible) (Ref: `Minijuego_Supaplex.md`)
- [ ] IA de Enemigo (Ciego/Sonido) (Ref: `Minijuego_Supaplex.md`)
- [ ] Lógica de Radio de Ruido (Excavación vs Bomba) (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Sigilo en Túneles Vacíos (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Semilla Persistente (Mismo nivel al reintentar) (Ref: `Minijuego_Supaplex.md`)
- [ ] Temporizador de Nivel y Gestión de Vidas (Ref: `Minijuego_Supaplex.md`)
- [ ] Mecánica de Trampas de Bloqueo (One-way) (Ref: `Minijuego_Supaplex.md`)
- [ ] Condición de Salida (Activación de puerta tras objetivo) (Ref: `Minijuego_Supaplex.md`)
- [ ] Puente de Inventario (Transferencia de items al Overworld) (Ref: `Minijuego_Supaplex.md`)

## 🟡 Feature: Minijuego B (Laberinto)
*Puede servir como transición/mapas secretos y pruebas de tiempo.*
- [ ] Shader de Niebla de Guerra / Sistema de Iluminación (Ref: `Minijuego_Laberinto.md`)
- [ ] Generación de laberinto y cambio de muros fuera de cámara (Ref: `Minijuego_Laberinto.md`)
- [ ] Sistema de recolección de objetos clave (Ref: `Minijuego_Laberinto.md`)
- [ ] Lógica de "Bucle Espacial" (Screen Wraparound) (Ref: `Minijuego_Laberinto.md`)
- [ ] IA de Enemigos (Drenado de luz) (Ref: `Minijuego_Laberinto.md`)

## 🟡 Feature: Minijuego C (Ritmo)
*Pensado para retos de timing y récords, ligado a habilidades o cosméticos.*
- [ ] Metrónomo sincronizado (AudioServer BPM) (Ref: `Minijuego_Ritmo.md`)
- [ ] Buffer de entrada y validación de timing (Ref: `Minijuego_Ritmo.md`)
- [ ] Validador de secuencias de comandos (Símbolos/Inputs) (Ref: `Minijuego_Ritmo.md`)
- [ ] Máquina de estados de multiplicadores/power-ups (Ref: `Minijuego_Ritmo.md`)
- [ ] Feedback visual de pulso y comandos (Ref: `Minijuego_Ritmo.md`)
