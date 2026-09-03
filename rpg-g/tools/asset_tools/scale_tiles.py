# ----------------------------------------
# Relaunch as root if needed
# ----------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Se requieren privilegios de superusuario."
    echo "Solicitando contraseña..."
    sudo "$0" "$@"
    exit $?
fi

# ----------------------------------------
import os
from PIL import Image

input_folder = "imagenes_in"
output_folder = "imagenes_out"

os.makedirs(output_folder, exist_ok=True)

scale_factor = 32 / 24  # 1.333333...
new_size = int(round(32 * scale_factor))  # 43 aprox

for file in os.listdir(input_folder):
    if file.lower().endswith(".png"):
        path = os.path.join(input_folder, file)
        img = Image.open(path).convert("RGBA")

        # Escalar (pixel perfect)
        img_scaled = img.resize(
            (new_size, new_size),
            resample=Image.NEAREST
        )

        # Recortar centro 32x32
        left = (new_size - 32) // 2
        top = (new_size - 32) // 2
        right = left + 32
        bottom = top + 32

        img_cropped = img_scaled.crop((left, top, right, bottom))

        output_path = os.path.join(output_folder, file)
        img_cropped.save(output_path)

print("Listo 🚀")
