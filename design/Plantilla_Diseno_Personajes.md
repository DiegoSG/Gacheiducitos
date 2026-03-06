# Plantilla de Diseño de Personajes

**Estilo Visual Objetivo:** 2.5D / Ilustración 2D a mano (Referencias: *Ogu and the Secret Forest* o *El Bosque Perdido*).
**Palabras clave:** Líneas limpias, formas redondeadas y amigables, colores planos vibrantes, sombreado suave.

---

## 1. Vistas Requeridas (Turnaround)
Cada personaje debe contar con una hoja de modelo con las siguientes alineaciones exactas:
* [ ] **Frente**
* [ ] **3/4 (Tres cuartos)** fundamental para la exploración.
* [ ] **Perfil**
* [ ] **Espalda**

## 2. Proporciones y Escala
* **Escala Base:** [ x ] Cabezas de alto (Definir la altura estándar, ej: 2.5 cabezas para personajes adorables).
* **Consistencia:** Mantener el grosor de línea (Lineart) uniforme sin importar el tamaño del personaje.

## 3. Paleta de Colores
Especificar colores exactos en código HEX/RGB para evitar variaciones:
* **Color Principal (Cuerpo/Ropa base):** `#HEX`
* **Color Secundario (Accesorios/Detalles):** `#HEX`
* **Color de Acento:** `#HEX`
* **Color de Sombra/Luz (Opcional si requiere tintes):** `#HEX`

## 4. Puntos de Articulación (Si aplica para animación tipo Spine)
Si el personaje se animará por partes, marcar (con cruces rojas) los puntos de pivote/corte:
* Cuello
* Hombros, Codos, Muñecas
* Cadera, Rodillas, Tobillos

## 5. Detalles y Expresiones Básicas
* [ ] Zoom a props o accesorios complejos (mochilas, armas, sombreros).
* [ ] **Expresiones mínimas requeridas:** Neutral, Alegre, Asustado/Sorprendido, Triste.

---
**Notas Técnicas para Exportación:**
* Resolución de trabajo recomendada: Canvas de **4K (3840 x 2160)**.
* Fondo: Transparente (o archivo fuente PSD/.clip por capas).
* Evitar gradientes complejos o efectos de post-procesado; el motor de juego o los shaders se encargarán de la iluminación dinámica si es necesaria.
