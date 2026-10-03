# Guía de Diseño: Uso de Ítems en Niveles

Esta guía explica cómo utilizar el sistema de ítems para poblar el mundo del juego y crear mecánicas de progresión.

## 1. Colocación de Ítems en el Escenario
Para colocar un ítem que el jugador pueda recoger:
1. Instancia la escena `PickupItem.tscn` (ubicada en `res://scenes/overworld/`).
2. En el inspector, busca la propiedad `Item Data`.
3. Arrastra el archivo `.tres` del ítem deseado desde `res://assets/items/data/` a esta propiedad.
4. El visual y la colisión se actualizarán automáticamente.

## 2. Tipos de Ítems Disponibles
Contamos con un set estándar para cubrir las necesidades básicas de diseño:

### Consumibles (Para supervivencia y buffs)
- **Poción Roja / Azul**: Recuperación de stats.
- **Pan**: Alimento básico.
- **Antídoto**: Utilizar para desbloquear áreas "venenosas" si tienes el ítem.

### Objetivos y Progresión (Llaves y Mapas)
- **Llave de Hierro**: Úsala para puertas cerradas estándar.
- **Llave Dorada**: Para puertas de "jefe" o tesoros importantes.
- **Mapa Antiguo**: Puede usarse como disparador de misiones (Quest Item).

### Botín y Materiales (Economía y Crafting)
- **Monedas de Oro**: El recurso principal.
- **Mineral de Hierro / Tronco de Madera**: Para sistemas de mejora o construcción.

## 3. Atributos Técnicos
Cada ítem tiene:
- **Rarity (Raridad)**: Influye en el color de la UI y el drop rate. (COMMON, UNCOMMON, RARE, EPIC, LEGENDARY).
- **Value (Valor)**: Precio base en tiendas o valor al ser vendido.
- **Stackable**: Define si el jugador puede llevar muchos en un solo slot.

---

### ¿Cómo crear nuevos ítems?
1. Haz clic derecho en la carpeta `res://assets/items/data/`.
2. Selecciona `Create New Resource`.
3. Busca `ItemData`.
4. Configura el ID (único), nombre, icono y propiedades.
5. ¡Listo! El `ItemDatabase` lo detectará automáticamente al iniciar el juego.
