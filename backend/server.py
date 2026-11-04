import asyncio
import hmac
import json
import mimetypes
import os
import sys
from http import HTTPStatus
from pathlib import Path

from dotenv import dotenv_values
from websockets.asyncio.server import broadcast, serve
from websockets.datastructures import Headers
from websockets.exceptions import ConnectionClosed
from websockets.http11 import Response

ADMIN = "admin"
ROOT = Path(__file__).parent.parent
ENV_FILE = ROOT / "frontend" / ".env"
DIST = (ROOT / "frontend" / "dist").resolve()

# Le variabili d'ambiente (es. su Render) hanno la precedenza sul file .env
env = {**dotenv_values(ENV_FILE), **os.environ}
ADMIN_USERNAME = env.get("ADMIN_USERNAME")
ADMIN_PASSWORD = env.get("ADMIN_PASSWORD")
HOST = env.get("SERVER_HOST") or "localhost"
PORT = int(env.get("SERVER_PORT") or env.get("PORT") or 8765)
if not ADMIN_USERNAME or not ADMIN_PASSWORD:
    sys.exit(f"Imposta ADMIN_USERNAME e ADMIN_PASSWORD in {ENV_FILE} o nell'ambiente")

guests = {}  # nome -> connessione
admin = None  # connessione dell'admin, se presente


def send_admin(**message):
    # broadcast non solleva errori se il destinatario si e' appena disconnesso
    if admin:
        broadcast([admin], json.dumps(message))


def send_guest_list():
    send_admin(type="guests", guests=sorted(guests))


def valid_login(data):
    if not isinstance(data, dict):
        return False
    username = str(data.get("username")).encode()
    password = str(data.get("password")).encode()
    username_ok = hmac.compare_digest(username, ADMIN_USERNAME.encode())
    password_ok = hmac.compare_digest(password, ADMIN_PASSWORD.encode())
    return username_ok and password_ok


def parse_json(text):
    try:
        return json.loads(text)
    except ValueError:
        return None


def from_admin(data):
    """data: {"to": nome del guest, oppure null per tutti, "text": messaggio}"""
    text = f"[{ADMIN}] {data['text']}"
    to = data.get("to")
    if to is None:
        broadcast(guests.values(), text)
    elif to in guests:
        broadcast([guests[to]], text)
    else:
        send_admin(type="error", text=f"{to} non e' connesso")


async def admin_session(ws):
    """Pagina web: login, poi messaggi JSON."""
    global admin

    if not valid_login(parse_json(await ws.recv())):
        await asyncio.sleep(1)  # rallenta i tentativi di indovinare la password
        await ws.send(json.dumps({"type": "login_error", "text": "Credenziali errate"}))
        return
    if admin:
        await ws.send(json.dumps({"type": "login_error", "text": "Admin gia' connesso"}))
        return

    admin = ws
    print("+ admin connesso")
    try:
        send_admin(type="login_ok")
        send_guest_list()
        async for message in ws:
            data = parse_json(message)
            if isinstance(data, dict) and isinstance(data.get("text"), str):
                print(f"admin -> {data.get('to') or 'tutti'}: {data['text']}")
                from_admin(data)
    finally:
        admin = None
        print("- admin disconnesso")


async def guest_session(ws):
    """client.py: il primo messaggio e' il nome, poi testo semplice."""
    name = await ws.recv()
    if not name or name == ADMIN or name in guests:
        await ws.send(f"(nome '{name}' non disponibile)")
        return

    guests[name] = ws
    print(f"+ {name} connesso")
    send_guest_list()
    try:
        async for text in ws:
            print(f"{name}: {text}")
            if admin:
                send_admin(type="message", **{"from": name}, text=text)
            else:
                broadcast([ws], "(admin non connesso)")
    finally:
        del guests[name]
        print(f"- {name} disconnesso")
        send_guest_list()


async def handler(ws):
    try:
        if ws.request.path == "/admin":
            await admin_session(ws)
        else:
            await guest_session(ws)
    except ConnectionClosed:
        pass


def serve_http(connection, request):
    """Richieste HTTP normali: controllo di Render e pagina compilata, se presente."""
    if request.headers.get("Upgrade"):
        return None  # WebSocket: prosegue verso handler

    path = request.path.partition("?")[0]
    if path == "/healthz":
        return connection.respond(HTTPStatus.OK, "OK\n")

    file = (DIST / path.lstrip("/")).resolve()
    if file == DIST:
        file = DIST / "index.html"
    # Solo file dentro dist/: niente .env o altri file del progetto
    if not file.is_relative_to(DIST) or not file.is_file():
        return connection.respond(HTTPStatus.NOT_FOUND, "Non trovato\n")

    body = file.read_bytes()
    content_type = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
    headers = Headers({"Content-Type": content_type, "Content-Length": str(len(body))})
    return Response(HTTPStatus.OK, "OK", headers, body)


async def main():
    async with serve(handler, HOST, PORT, process_request=serve_http) as server:
        print(f"Server in ascolto su ws://{HOST}:{PORT}")
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
