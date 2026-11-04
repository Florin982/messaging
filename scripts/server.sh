#!/usr/bin/env bash
# Avvia il server. Uso: scripts/server.sh
source "$(dirname "$0")/common.sh"

cd "$ROOT"
exec "$PYTHON" -u backend/server.py
