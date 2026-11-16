#!/usr/bin/env bash
# Exporta la versión web (un solo hilo, sin cabeceras COOP/COEP) y la despliega en Vercel.
# Uso: GODOT=/ruta/Godot_v4.7.1-stable_win64_console.exe web/deploy.sh   (desde waos/)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
cp web/vercel.json build/web/vercel.json
npx -y vercel@latest deploy build/web --prod --yes
