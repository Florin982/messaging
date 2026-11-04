#!/usr/bin/env bash
# Avvia la pagina admin e la apre nel browser. Uso: scripts/admin.sh
source "$(dirname "$0")/common.sh"

PORT=5173
URL="http://localhost:$PORT"

open_browser() {
  for _ in {1..100}; do
    if (exec 3<>"/dev/tcp/localhost/$PORT") 2>/dev/null; then
      if command -v explorer.exe >/dev/null; then
        # explorer.exe restituisce un errore anche quando riesce
        explorer.exe "$URL" || true
      elif command -v xdg-open >/dev/null; then
        xdg-open "$URL"
      fi
      return
    fi
    sleep 0.1
  done
}

cd "$ROOT/frontend"
[[ -d node_modules ]] || npm install
open_browser &
# vite direttamente (come fa npm run dev): npm non gli inoltrerebbe lo stop di all.sh
exec node_modules/.bin/vite
