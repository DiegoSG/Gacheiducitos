# Guía de Uso del Pipeline de Eventos (GameTrigger)

Bienvenido a la documentación oficial del sistema `GameTrigger`. Esta arquitectura está diseñada para permitir armar cinemáticas complejas, gestionar progreso narrativo y controlar la lógica del nivel **sin escribir una sola línea de código extra**. El sistema funciona como una lista de reproducción (array) que ejecuta acciones secuenciales o paralelas en la escena.

---

## 1. El Nodo Principal: `GameTrigger`
Cualquier evento interactivo del mapa utilizará este nodo base (es un `Area2D` con poderes extendidos).  

### Modos de Activación (`Trigger Mode`)
En el Panel del Inspector de un GameTrigger podrás definir cómo quieres que la historia comience:
- **`ON_ENTER`**: Se dispara nativamente cuando un personaje que pertenece a cierta capa de colisión lo toca. (Muy útil para emboscadas o checkpoints invisibles).
- **`ON_EXIT`**: Se dispara cuando el actor **abandona** el área. (Útil para cerrar puertas a sus espaldas).
- **`INTERACT`**: Funciona como un NPC u Objeto Táctil clásico. El jugador debe ponerse encima/enfrente y apretar el botón de Acción (`ui_accept`).
- **`AUTO_START`**: En cuanto arranca la escena, la secuencia comienza de golpe. (Usado primordialmente para continuar historias luego de salir de un minijuego, siempre bloqueado por una Condición de Bandera).

### `One Shot`
- Si la casilla está **activada**, esta secuencia ocurrirá **solo una vez en toda la partida** y el trigger quedará deshabilitado para siempre en cuanto lo pises.
- Si está **desactivada**, la secuencia se volverá a repetir cada vez que las condiciones se den.

### Filtrar a Quién lo Activa (Collision Masks)
Para asegurar que solo el Villano, o solo una Caja que estás empujando dispare el trigger, navega hasta la propiedad estándar `Collision -> Mask` de tu GameTrigger, y habilita **únicamente la Capa (Layer) que pertenezca a ese objeto**.

---

## 2. Configurando Condiciones (Banderas/Flags)
El sistema permite bifurcar eventos en base a tus variables del juego usando el módulo de `Condición`:

1.  Habilita `Require Condition` a **True**.
2.  **`Condition Flag`**: El nombre exacto de tu variable (ej. `has_key` o `boss_defeated`).
3.  **`Condition Expected Value`**: El valor que esperas que tenga la bandera. Puedes usar `true`, `false` o números directos.

El Trigger tratará de comparar esto con tu `NarrativeManager`. Si resulta ser verdad, se reproduce el bloque `Actions If True`. Si resulta ser falso, reproduce el bloque de fallos `Actions If False` (ideal para poner un NPC diciendo *"¡No tienes la llave, lárgate!"*).

---

## 3. Entendiendo la Secuencia de Acciones (El Timing)
El array de elementos se lee **estrictamente de Arriba hacia Abajo**.

La magia visual recae en un parámetro que encontrarás dentro de todas las Acciones: la casilla **`Wait To Finish`**:
- **Desmarcado (Apagado):** La acción se dispara y el sistema salta de inmediato a leer el siguiente ítem del array en el mismo instante. Varias acciones seguidas con este botón apagado provocan efectos que ocurren **todos a la vez, simultáneamente**.
- **Marcado (Encendido):** La acción se inicia y el sistema entra en **PAUSA**. Retendrá el avance de la lista general hasta que esta acción (ya sea animación o diálogo) termine al 100%.

> [!TIP]
> **Ejemplo de Timings Simples:**
> 1. `VisColAction` (Abre una compuerta invisible). `Wait to Finish` = Apagado.
> 2. `AnimAction` (Una explosión). `Wait to Finish` = Encendido.
> 3. `SpawnAction` (Suelta humo en pantalla). `Wait to Finish` = Apagado.
> 4. `DialogueAction` ("¡Vaya sorpresa!"). `Wait to Finish` = Encendido.

---

## 4. Tipos de Acciones Disponibles (`ActionResource`)
Al añadir Elementos a tus arrays (If True o If False), selecciona y elige de esta librería:

- **`AnimAction`**  
  Busca un `AnimationPlayer` o un `AnimatedSprite2D` y manda reproducir una secuencia usando "Animation Name". *(Aviso: Cuidado con las animaciones marcadas en bucle 'Loop' nativamente; si además les pides `Wait To Finish`, el juego se quedará esperando a una animación que nunca acaba).*
  
- **`VisColAction`**  
  Apaga o enciende la renderización (`is_visible`) de un objeto y desactiva/activa TODOS sus polígonos de colisión (`collisions_enabled`) recursivamente. Perfecto para tapar hoyos, derribar paredes o esconder entidades.

- **`SpawnAction`**  
  Instancia o "spawnea" un archivo empaquetado `.tscn` en un punto específico relativo al Trigger (`relative_to_parent`: True) o absoluto.

- **`WaitAction`**  
  Agrega simples pausas muertas de guion en la línea de tiempo. Ejemplo: Pides que espere 2.5 segundos para fines de impacto narrativo antes de continuar.

- **`ToggleTriggerAction`**  
  Te permite apagar o encender el sistema de colisión de OTRO `GameTrigger` distinto usando un `NodePath`. *(Ej: Luego de entregar la Espada Mágica, habilitas el Trigger de la Emboscada Final en la pradera).*

- **`RunTriggerAction`**  
  Llama de forma directa y remota a las secuencias de otro `GameTrigger` forzándolo a empezar instantáneamente su bloque, aún sin que el jugador haya caminado por encima (comportando sus chequeos de OneShot nativos).

- **`DialogueAction`**  
  Dispara tu sistema de diálogo (usualmente usando el plugin predefinido DialogManager). Usa el `dialogue_resource` `.dialogue` y el knot/título objetivo.

- **`MinigameAction` / `LevelAction`**  
  Las opciones potentes para cargar pantallas nuevas. Usa el parámetro de configuración del nivel/minijuego.

> [!WARNING]
> **ATENCIÓN DE VIDA O MUERTE**: Acciones como `MinigameAction` y `LevelAction` destruyen la escena del Overworld original para ahorrar memoria. **SIEMPRE deben ser tu ÚLTIMO ítem en el Array.** El Trigger desaparecerá de la RAM tras ejecutarlas y ningún ítem debajo de estas se llegará a correr jamás.

---

## 5. Arquitectura de Transmisión Continua (Regresar de Minijuegos)

Si tienes que contar una historia que suceda: `"Antes de minijuego" -> Entra al Minijuego -> "Después de ganarlo"`, deberás conectarlos usando Flags inter-escenas, ya que el Trigger original no sobrevive a la transición de pantallas.

1.  **Fase 1 (Acertijo Inicial):** Un trigger manda un `DialogueAction` seguido de un `MinigameAction`.
2.  **Durante el minijuego:** Tras programar que gane el reto, tu lógica sube un flag: `NarrativeManager.set_flag("desafio_uno_completado", true)` poco antes de regresar a la pantalla principal.
3.  **Fase 2 (Recompensas Finales):** Ubica en el mapa original donde se supone que volverá el jugador un nuevo `GameTrigger`. Configúralo en **Trigger Mode: `AUTO_START`**. Pídele como Condición que la bandera `desafio_uno_completado` valga `true`. 
    - Como acción `[0]` de este nuevo bloque agregas un `FlagAction` pasando la banderilla a `false` o `terminado` para evitar bucles infinitos en futuras visitas al nivel.
    - Como resto del bloque pones tus diálogos de aplausos, ítems recompensados y fanfarrias. Todo correrá de golpe y en flujo natural con protección anti caídas del sistema.
