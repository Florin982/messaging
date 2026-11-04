import os
import sys
import threading
from pathlib import Path

from dotenv import dotenv_values
from websockets.exceptions import ConnectionClosed
from websockets.sync.client import connect

ENV_FILE = Path(__file__).parent / "client.env"
URL = dotenv_values(ENV_FILE).get("SERVER_URL") or "ws://localhost:8765"


def receive(ws):
    try:
        for text in ws:
            print(text, flush=True)
    except ConnectionClosed:
        pass
    print("(connessione chiusa)", flush=True)
    os._exit(0)  # sblocca anche input() nel thread principale


def main():
    if len(sys.argv) != 2:
        sys.exit("Uso: scripts/client.sh <nome>")

    with connect(URL) as ws:
        ws.send(sys.argv[1])
        threading.Thread(target=receive, args=(ws,), daemon=True).start()
        try:
            while True:
                text = input()
                if text:
                    ws.send(text)
        except (EOFError, KeyboardInterrupt):
            pass


if __name__ == "__main__":
    main()
