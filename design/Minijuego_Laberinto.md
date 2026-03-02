# Diseño Detallado: Las Raíces del Olvido (Laberinto)

## 1. Visión General
Un minijuego de exploración tensa donde el jugador debe navegar por un laberinto orgánico que cambia de forma. El tema es la pérdida de identidad y la confusión.

## 2. Mecánicas Únicas

### A. Niebla de Guerra Orgánica
- El mapa está oculto por una oscuridad total.
- El jugador emite un círculo de luz limitado.
- La luz disminuye si el jugador se queda quietos (simbolizando el olvido), obligándolo a avanzar.

### B. Laberinto Dinámico (Shifting Walls)
- Ciertas secciones de muros son "raíces" que se retraen o crecen.
- **Trigger:** Los muros cambian cuando el jugador no los está mirando (fuera del círculo de luz), creando una sensación de desorientación.

### C. Wrap-around (Bucle Espacial)
- Si el jugador sale por el borde derecho, aparece por el izquierdo. 
- Esto se usará para puzzles donde el camino "recto" nunca lleva a la salida.

## 3. Elementos del Juego
- **Fragmentos de Identidad:** Coleccionables que restauran el círculo de luz y cuentan breves líneas de historia.
- **Sombras del Pasado:** Enemigos lentos que drenan la luz si te tocan.
- **La Salida:** Un portal luminoso que solo aparece cuando se han recolectado suficientes fragmentos.

## 4. Implementación Técnica (Godot)
- **Shader de Luz:** Un CanvasLayer con un shader de gradiente radial para la neblina.
- **Navegación:** Uso de `NavigationRegion2D` que se actualiza dinámicamente cuando las raíces cambian.
- **Lógica de Cambio:** Un script que detecta qué celdas del TileMap están fuera del `VisibleOnScreenNotifier2D` para permutarlas.

## 5. Tareas Técnicas
- [ ] Implementar Shader de Niebla de Guerra.
- [ ] Sistema de regeneración de obstáculos fuera de cámara.
- [ ] Mecánica de "Wraparound" en los bordes de la pantalla.
