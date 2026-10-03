#!/usr/bin/env bash

# Ir al directorio donde se encuentra este script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

# Verificar si node_modules existe, si no, instalar dependencias
if [ ! -d "node_modules" ]; then
    echo "Instalando dependencias necesarias..."
    npm install
fi

echo "Iniciando DialogueApp..."

# Si ya hay una instancia corriendo en el puerto 3131, cerrarla primero
PID=$(lsof -ti:3131 2>/dev/null)
if [ ! -z "$PID" ]; then
    echo "Cerrando instancia previa en el puerto 3131 (PID: $PID)..."
    kill -9 $PID 2>/dev/null
fi

# Arrancar el servidor en segundo plano
node server.js &
SERVER_PID=$!

# Esperar a que el servidor esté listo
sleep 1

# Intentar abrir automáticamente en el navegador por defecto
URL="http://localhost:3131"
echo "Abriendo $URL en tu navegador..."

if command -v xdg-open > /dev/null; then
    xdg-open "$URL" > /dev/null 2>&1 &
elif command -v gnome-open > /dev/null; then
    gnome-open "$URL" > /dev/null 2>&1 &
elif command -v sensible-browser > /dev/null; then
    sensible-browser "$URL" > /dev/null 2>&1 &
fi

echo "============================================="
echo " DialogueApp está en ejecución (PID: $SERVER_PID)"
echo " Servidor disponible en: $URL"
echo " Presiona Ctrl+C para detener el servidor"
echo "============================================="

# Mantener la consola abierta escuchando el proceso y manejar la salida limpia con Ctrl+C
trap "echo -e '\nDeteniendo DialogueApp...'; kill $SERVER_PID 2>/dev/null; exit 0" INT TERM
wait $SERVER_PID
