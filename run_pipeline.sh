#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[PIPELINE]"

echo "$LOG_TAG === INICIANDO STAGE 2 (Bootstrap & SDKMAN) ==="
# Asegúrate de cargar SDKMAN y ejecutar tu stage 2
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Ejecutas tu script de la stage 2 (asumiendo que se llama setup.sh)
./setup.sh

echo "$LOG_TAG === INICIANDO STAGE 3 (Scaffold Kotlin App) ==="
# Ejecutas el script de la stage 3 que acabamos de crear, 
# pasando opcionalmente el nombre del proyecto y el paquete
./stage3-scaffold.sh "MiAppModular" "com.miempresa.miapp"

echo "$LOG_TAG === ¡FLUJO COMPLETADO CON ÉXITO! ==="