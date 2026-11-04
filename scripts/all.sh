#!/usr/bin/env bash
# Avvia server, pagina admin e guest. Ctrl+C ferma il server e chiude i guest.
# Uso: scripts/all.sh [nomi dei guest]    (predefiniti: bob carol)
source "$(dirname "$0")/common.sh"

SCRIPTS="$ROOT/scripts"
PORTS=(8765 5173)
GUESTS=("$@")
[[ ${#GUESTS[@]} -gt 0 ]] || GUESTS=(bob carol)

port_open() { (exec 3<>"/dev/tcp/localhost/$1") 2>/dev/null; }

for port in "${PORTS[@]}"; do
  if port_open "$port"; then
    echo "La porta $port e' gia' in uso: server o pagina admin sono gia' avviati?" >&2
    exit 1
  fi
done

"$SCRIPTS/server.sh" &
SERVER_PID=$!
ADMIN_PID=""
trap 'kill "$SERVER_PID" $ADMIN_PID 2>/dev/null || true' EXIT

for _ in {1..50}; do
  port_open "${PORTS[0]}" && break
  kill -0 "$SERVER_PID" 2>/dev/null || { wait "$SERVER_PID" || true; exit 1; }
  sleep 0.1
done

"$SCRIPTS/admin.sh" </dev/null &
ADMIN_PID=$!

for name in "${GUESTS[@]}"; do
  if command -v wt.exe >/dev/null && [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    wt.exe -w 0 new-tab --title "$name" wsl.exe -d "$WSL_DISTRO_NAME" -- "$SCRIPTS/client.sh" "$name"
  else
    echo "Avvia il guest in un altro terminale: $SCRIPTS/client.sh $name"
  fi
done

echo "Tutto avviato. Premi Ctrl+C per fermare."
trap 'exit 0' INT TERM
wait "$SERVER_PID"
