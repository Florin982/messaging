# Parti comuni agli script: va incluso con "source", non eseguito.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$ROOT/.venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
  echo "Ambiente non trovato: segui \"Installazione\" nel README." >&2
  exit 1
fi
