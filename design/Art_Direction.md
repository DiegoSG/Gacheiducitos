# Directrices de Dirección de Arte

## Pilares Visuales
1.  **Legibilidad:** Los elementos del minijuego deben distinguirse instantáneamente del arte de fondo.
2.  **Atmósfera:** El estilo visual debe reflejar el estado narrativo (por ejemplo, con fallas para "Código", etéreo para "Memoria").
3.  **Cohesión:** La interfaz de usuario, los sprites y los efectos deben compartir una paleta de colores unificada.

## Estilo Propuesto: "El Vacío Etéreo" (Coincide con Concepto C)
- **Estilo Base:** Estética minimalista dibujada a mano (como bocetos en papel) o arte vectorial limpio.
- **Paleta de Colores:**
    - **Fondos:** Blanco roto, crema, gris claro (textura de papel).
    - **Objetos Interactivos:** Líneas de tinta negra de alto contraste.
    - **Magia/Memoria:** Manchas de acuarela vibrantes (Cian, Magenta, Dorado).
- **Iluminación:** Iluminación global suave tipo "bloom" para dar una sensación onírica.
- **UI:** Texto flotante, elementos diegéticos (texto incrustado en el mundo en lugar de en un HUD).

## Estilo Alternativo: "Fallo de Neón" (Coincide con Concepto A)
- **Estilo Base:** Modo oscuro, líneas de escaneo CRT, aberración cromática.
- **Paleta de Colores:** Cyberpunk (Rosa Neón, Verde Ácido, Púrpura Profundo) contra Negro.
- **UI:** Fuente de Terminal/Consola (Monoespaciada), cursores parpadeantes.

## Solicitudes de Referencia
Para finalizar el estilo, necesitamos decidir sobre:
- **Proporciones de Personajes:** ¿Chibi (2 cabezas de altura), Realista (7-8 cabezas) o Abstracto?
- **Perspectiva:** ¿Top-Down (Zelda) o Isométrica (Hades)?

## Reglas de Colisión e Interacción Automatizadas

Para mantener la consistencia y facilitar el desarrollo, los objetos seguirán estas reglas basadas en su sprite:

1.  **Área de Interacción (InteractionArea):**
    *   **Tamaño:** Cubre todo el sprite + un margen de 4-8px.
    *   **Propósito:** Debe ser fácil de cliquear/activar desde cualquier ángulo.
    *   **Forma:** Generalmente un Rectángulo o Círculo centrado.

2.  **Colisión Física (PhysicsCollision):**
    *   **Tamaño:** Cubre solo el 25-30% inferior del sprite (la "base").
    *   **Ancho:** 80-90% del ancho del sprite.
    *   **Posición:** Alineado con la parte inferior del sprite.
    *   **Propósito:** Permitir perspectiva 2.5D (el personaje puede caminar "detrás" del objeto).

**Futura Implementación:**
Crear un script `AutoCollider` que tome prestadas las dimensiones del `Sprite2D` y genere estas formas automáticamente en el `_ready()`.
