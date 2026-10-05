# Sistema de Audio

Lista de eventos y decisiones (música, efecto o silencio): hoja "Gacheiducitos - Eventos de Audio" en Drive. La columna "ID de audio" es el identificador que usa el código.

## Piezas
- **`AudioManager`** (autoload, `src/core/audio_manager.gd`): reproduce por identificador.
  - `play_music(id, fade_time)` / `stop_music(fade_time)`: música con fundido entre pistas. Si la pista pedida ya suena, no se reinicia.
  - `play_sfx(id)`: efecto de juego. Se corta cuando el juego se pausa.
  - `play_ui(id)`: efecto de interfaz. Suena con el juego pausado (menús, inventario, mapa, diálogos, guardado).
  - `get_playable_entry(id)`: para nodos con reproductor propio (sonidos en bucle o posicionales).
  - `set_bus_volume` / `get_bus_volume` / `save_settings`: volumen de los buses `Music` y `SFX`, guardado en `user://settings.cfg`.
- **Catálogo** (`data/audio/audio_catalog.tres`, recurso `AudioCatalog` con entradas `AudioEntry`): cada entrada tiene `id`, `stream` y `volume_db`.
- **Buses** (`default_bus_layout.tres`): `Master`, `Music` (con un efecto Amplify que atenúa la música en pausa) y `SFX`.
- **`SceneMusic`** (`src/core/components/scene_music.gd`): nodo que se agrega a una escena para que suene su música al entrar. `alert_music_id` cambia a otra música mientras el mundo está en alerta.
- **`PlaySoundAction`** (`src/core/pipeline/actions/play_sound_action.gd`): acción del pipeline de GameTrigger para reproducir un efecto, un sonido de interfaz o cambiar la música.

## Comportamiento
- Un identificador sin sonido asignado no suena y avisa una vez por consola. Un identificador que no está en el catálogo también avisa una vez.
- Pausa (menú de pausa, inventario, diálogos): la música baja 10 dB y los efectos de juego se cortan. Los efectos de interfaz siguen sonando.
- Al morir suena `music_death`; al reaparecer, el nivel se recarga y su `SceneMusic` vuelve a poner la música del nivel.

## Asignar un sonido
1. Copiar el archivo a `rpg-g/assets/audio/music/` o `rpg-g/assets/audio/sfx/` (`.ogg` para música, `.wav` u `.ogg` para efectos).
2. Abrir `data/audio/audio_catalog.tres` en el Inspector, buscar la entrada por su `id` y arrastrar el archivo a `stream`. Ajustar `volume_db` si hace falta.
3. Música y sonidos en bucle (`sfx_portal_hum`, `sfx_smash_insect_loop`): activar Loop en la pestaña Import del archivo.

## Agregar un evento nuevo
1. Agregar una entrada `AudioEntry` con el `id` nuevo al catálogo.
2. Llamar `AudioManager.play_sfx(&"id")` (o `play_ui` / `play_music`) en el punto del código donde ocurre el evento.
3. Agregar la fila a la hoja de eventos.

## Prueba
`src/core/tests/test_audio.tscn`: asigna tonos generados en memoria a algunos IDs y tiene botones para música con fundido, efectos, pausa, IDs sin sonido y volumen.
