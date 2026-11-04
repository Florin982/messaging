#!/usr/bin/env bash
# Avvia un guest. Uso: scripts/client.sh <nome>
source "$(dirname "$0")/common.sh"

cd "$ROOT"
exec "$PYTHON" -u backend/client.py "$@"
