# Diseño Técnico: MG_Excavation (Excavación)

## 1. Concepto Mecánico
Puzzle de acción en rejilla (Grid-based) donde el jugador excava túneles bajo tierra. Se hereda la lógica de gravedad de los clásicos de excavación para las piedras y el movimiento celda a celda.

## 2. Elementos del Juego (Tiles e Items)
| Elemento | Comportamiento |
| :--- | :--- |
| **Jugador** | Excavador con pala. Elimina "Tierra" al moverse. |
| **Piedra** | Cae si tiene aire debajo. Mata al jugador si lo aplasta. |
| **Tierra** | Ocupa las celdas iniciales. Bloquea el paso pero es excavable. |
| **Items de Misión** | Objetos específicos (ej: Raíces) necesarios para completar el objetivo. |
| **Items de Recompensa** | Monedas, Corazones, etc. Se suman al inventario global. |
| **Punto de Rescate** | Celda que contiene un NPC. Se activa al entrar en ella. |
| **Muro Irrompible** | Inamovible, ignora explosiones y no se puede excavar. |
| **Muro Rompible** | No se puede excavar, pero se destruye con bombas. |
| **Bomba (Item)** | Item recolectable. Al activarse, explota tras un retardo. |
| **Acechador (Enemigo)** | Entidad que patrulla y caza al jugador basado en ruido. |
| **Salida** | Se habilita solo cuando el objetivo de la misión se cumple. |
| **Trampa de Bloqueo** | Tile que se convierte en Muro Irrompible tras ser cruzado, sellando el camino. |

## 3. Sistema de Misiones (Mission Logic)
Antes de entrar al minijuego, el `GameManager` pasará una estructura de datos con el objetivo:
- `tipo_objetivo`: `COLLECT` (Cosechar N items) o `RESCUE` (Encontrar NPC).
- `cantidad_objetivo`: Número de items necesarios.
- `items_extra`: Lista de loot posible en el nivel.

## 4. Generación Procedimental (Procedural Generation)
Para evitar el diseño manual, usaremos un generador basado en **Autómatas Celulares** para crear cuevas orgánicas.

### Algoritmo Propuesto:
1.  **Mapa Inicial:** Llenar el grid con un 40-50% de Tierra (Semilla Aleatoria).
2.  **Suavizado (Smooth):** Aplicar reglas de vida (Moore Neighborhood) para agrupar la tierra.
3.  **Distribución de Objetos:**
    *   **Piedras:** Colocadas en clusters en el espacio vacío.
    *   **Items/Raíces:** Distribuidas basándose en la distancia al punto de inicio (Dijkstra map).
4.  **Validación:** Uso de *Flood Fill* para asegurar que el objetivo es alcanzable.

## 5. Parámetros de Dificultad
- `probabilidad_piedra`: Frecuencia de obstáculos que caen.
- `densidad_tierra`: Cantidad de bloques a excavar (más tierra = más lento, menos tierra = más peligro de piedras).
- `distancia_objetivo`: Profundidad mínima del objetivo.

## 7. Mecánica de Bombas
- **Colocación:** El jugador puede soltar una bomba en su celda actual.
- **Explosión:** Tras 2 segundos, detona en un área de **3x3**.
- **Destrucción:** Afecta a Tierra, Muros Rompibles, Rocas y Entidades. No afecta a Muros Irrompibles.

## 8. IA del Acechador (Blind/Sound AI)
El enemigo es ciego y se guía exclusivamente por las vibraciones en el terreno.

### Reglas de Detección:
1.  **Cercanía Absoluta:** Si el jugador está a **1 celda de distancia**, el Acechador siempre detecta su posición (latidos/respiración).
2.  **Ruido por Excavación:** Cavar Tierra genera una vibración que atrae al Acechador si este se encuentra en un radio de acción determinado.
3.  **Ruido por Bombas:** Una explosión genera un ruido global (o de muy largo alcance) que atrae a todos los enemigos cercanos hacia el epicentro.
4.  **Sigilo (Zonas Excavadas):** Moverse por celdas que ya están vacías (sin cavar) **no genera ruido**. El jugador puede usar esto para flanquear o esconderse.
5.  **Obstáculos:** Las piedras o muros bloquean el paso del enemigo, obligándolo a recalcular su ruta hacia el último ruido escuchado.

### Estados:
1.  **Idle/Patrulla:** Se mueve lentamente por zonas vacías.
2.  **Rastreo:** Se mueve hacia la última celda donde se detectó una vibración (Excavación o Bomba).

## 9. Factor Tiempo y Persistencia
### A. Tiempo Límite
- Cada nivel tiene un `tiempo_limite` (ej: 3:00 min).
- Si el tiempo llega a 0:
    - Se resta una vida al jugador.
    - Se expulsa al jugador al Overworld.

### B. Persistencia del Nivel (Seed Persistence)
Para asegurar que un desafío sea superable mediante la práctica:
- El `GameManager` almacenará un `current_level_seed` cuando un NPC dispare el minijuego.
- **Mismo Nivel en Retransmisión:** Si el jugador muere o se le acaba el tiempo, al reentrar se usará la misma semilla para generar exactamente el mismo mapa.
- **Limpieza de Seed:** La semilla solo se borra si el jugador GANA o si cancela la misión explícitamente hablando con el NPC.

### C. Zonas de Cierre (One-way Paths)
- El generador colocará "Trampas de Bloqueo" en pasillos críticos.
- Al pasar, el tile se transforma en `Muro Irrompible`. Esto obliga al jugador a avanzar y no poder retroceder hacia la seguridad de los túneles vacíos.

## 10. Arquitectura de Código
- **`LevelGenerator.gd`**: Usa la `seed` del GameManager para la generación.
- **`MG_ExcavationGame.gd`**: Controla el array 2D y la física.
- **`MissionManager.gd`**: Gestiona el tiempo y el objetivo.

## 5. Checks Técnicos de Implementación
- [x] Lógica de excavación (reemplazar Tile Tierra por Vacío).
- [x] Lógica de gravedad de piedras (caída vertical y deslizamiento lateral).
- [ ] Contador de objetivos dinámico (UI interna del minijuego).
- [x] Sistema de "Game Over" por aplastamiento.
- [ ] Transferencia de loot al estado global del jugador tras la victoria.
- [x] Interpolación visual suave y rotación de piedras.
- [x] Cámara de seguimiento con límites escalados.
