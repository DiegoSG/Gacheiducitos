extends Node
class_name CheckpointLevel

## Componente marcador que indica que la escena actual es un nivel Checkpoint (Zona Segura / Respawn).
## Al entrar a un nivel con este componente, el GameManager lo registra como el checkpoint activo
## y almacena un snapshot del jugador para restaurarlo en caso de muerte.
