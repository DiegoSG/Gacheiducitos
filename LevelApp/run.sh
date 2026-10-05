#!/usr/bin/env bash

# Ir al directorio donde se encuentra este script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "Iniciando LevelApp..."

# Si ya hay una instancia corriendo en el puerto 3132, cerrarla primero
PID=$(lsof -ti:3132 2>/dev/null)
if [ ! -z "$PID" ]; then
    echo "Cerrando instancia previa en el puerto 3132 (PID: $PID)..."
    kill -9 $PID 2>/dev/null
fi

node server.js &
SERVER_PID=$!
sleep 1

URL="http://localhost:3132"
echo "Abriendo $URL en tu navegador..."
if command -v xdg-open > /dev/null; then
    xdg-open "$URL" > /dev/null 2>&1 &
elif command -v sensible-browser > /dev/null; then
    sensible-browser "$URL" > /dev/null 2>&1 &
fi

echo "============================================="
echo " LevelApp está en ejecución (PID: $SERVER_PID)"
echo " Servidor disponible en: $URL"
echo " Presiona Ctrl+C para detener el servidor"
echo "============================================="

trap "echo -e '\nDeteniendo LevelApp...'; kill $SERVER_PID 2>/dev/null; exit 0" INT TERM
wait $SERVER_PID
