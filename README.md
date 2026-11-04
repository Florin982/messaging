# Chat admin/guest su WebSocket

## Installazione

    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    cp frontend/.env.example frontend/.env   # poi imposta una password
    (cd frontend && npm install)             # serve Node.js

## Avvio

Tutto insieme (server, pagina admin e un guest per scheda di Windows Terminal):

    scripts/all.sh                # guest predefiniti: bob e carol
    scripts/all.sh anna luca      # guest a scelta

Ctrl+C ferma il server e chiude i guest. Oppure un pezzo alla volta, ognuno nel suo terminale:

    scripts/server.sh
    scripts/admin.sh
    scripts/client.sh bob

## Collegarsi come guest dal cmd di Windows

Con il server gia' avviato, apri `cmd` sullo stesso PC e sostituisci `mario` con il tuo nome:

    wsl -d Ubuntu-24.04 -- /home/flo/githubProjects/messagging-server-client/scripts/client.sh mario

Scrivi un messaggio e premi Invio per inviarlo all'admin. `Ctrl+C` per uscire.

Per lasciarlo in background, in una finestra ridotta a icona (il comando ti restituisce subito il prompt):

    start /min wsl -d Ubuntu-24.04 -- /home/flo/githubProjects/messagging-server-client/scripts/client.sh mario

Riapri la finestra dalla barra delle applicazioni per leggere e scrivere.

### Chiudere il client

- Dalla finestra: riaprila e premi `Ctrl+C`, oppure chiudila con la X.
- Da un terminale WSL (sostituisci `mario` con il nome del guest):

      pkill -f "client.py mario"

- Dal `cmd` di Windows:

      wsl -d Ubuntu-24.04 -- pkill -f "client.py mario"

Questi due comandi chiudono anche i client il cui nome inizia allo stesso modo (es. `mario2`).
Evita `wsl --shutdown` e `taskkill /IM wsl.exe`: fermerebbero anche il server e gli altri programmi in WSL.

## Collegarsi come guest da Windows senza WSL

Serve una copia del progetto in una cartella di Windows
(bastano `backend\client.py` e `scripts\client.bat`). Se il server e' su un'altra macchina,
aggiungi anche `backend\client.env` (vedi "Pubblicare su un server").

Fai doppio clic su `scripts\client.bat` (ti chiede il nome) oppure, da `cmd`:

    scripts\client.bat mario

La prima volta prepara da solo l'ambiente Python in `.venv-win` e installa `websockets`.
Se Python manca, scarica l'ultima versione da python.org, ne verifica la firma e la installa
solo per il tuo utente. Se Python c'e' gia', non scarica nulla.
Scrivi un messaggio e premi Invio per inviarlo all'admin. `Ctrl+C` per uscire.

## Pubblicare su Render

`render.yaml` crea un solo servizio che serve sia la pagina admin sia il WebSocket, con HTTPS incluso.

1. Metti il progetto su GitHub, GitLab o Bitbucket (`.gitignore` esclude gia' `frontend/.env`).
2. Su Render: **New > Blueprint**, scegli il repository e conferma.
3. Trovi la password admin nel servizio, in **Environment** (`ADMIN_PASSWORD`, generata da Render).
4. La pagina admin e' `https://<nome-servizio>.onrender.com`.
5. Ai guest dai `backend/client.env` con il tuo indirizzo:

       SERVER_URL=wss://<nome-servizio>.onrender.com

Il piano `free` si spegne dopo 15 minuti senza traffico e impiega circa un minuto a ripartire:
quando si spegne o si riavvia, tutti vengono disconnessi. Se non va bene, cambia `plan` in
`render.yaml`. Chiunque conosca l'indirizzo puo' entrare come guest.

## Pubblicare su un server

Di base tutto usa `localhost`. Per un server vero (`203.0.113.10` e' un esempio):

1. Sul server, in `frontend/.env`, aggiungi:

       SERVER_HOST=0.0.0.0
       SERVER_PORT=8765
       VITE_SERVER_URL=ws://203.0.113.10:8765/admin

2. Crea la pagina admin e pubblica **solo** `frontend/dist/`, mai tutta `frontend/`
   (`VITE_SERVER_URL` viene letto qui: se lo cambi, ripeti il comando):

       cd frontend && npm run build

3. Avvia il server con `scripts/server.sh` e apri la porta 8765 nel firewall.
4. Ai guest dai `backend/client.env` (modello: `backend/client.env.example`), senza la password admin:

       SERVER_URL=ws://203.0.113.10:8765

**Attenzione:** con `ws://` la password admin e i messaggi viaggiano in chiaro su Internet,
e chiunque conosca l'indirizzo puo' entrare come guest. `ws://` va bene solo per una prova o
in una rete fidata. Per Internet usa un dominio e HTTPS, per esempio con Caddy:

    chat.tuodominio.it {
        @ws {
            header Connection *Upgrade*
            header Upgrade websocket
        }
        reverse_proxy @ws localhost:8765
        root * /percorso/del/progetto/frontend/dist
        file_server
    }

In questo caso lascia `SERVER_HOST=localhost`, non aprire la porta 8765 e usa
`VITE_SERVER_URL=wss://chat.tuodominio.it/admin` e `SERVER_URL=wss://chat.tuodominio.it`.

## Funzionamento

- I messaggi dei guest arrivano solo all'admin; i guest non parlano tra loro.
- L'admin accede con le credenziali di `frontend/.env`, vede gli utenti connessi e
  clicca su un utente per aprire la chat con lui, o su "Tutti" per scrivere a tutti.
- La pagina admin e' fatta con Vue e si avvia con `npm run dev` da `frontend/`
  (http://localhost:5173); `scripts/admin.sh` lo fa per te e apre il browser.
- `frontend/.env` e' letto solo da `server.py`, che va riavviato se lo modifichi.
  Non copiare mai `frontend/` cosi' com'e' su un server web: esporresti anche `.env`.
- I guest non hanno password e la connessione non e' cifrata: solo per uso locale.
- La cronologia sta nella pagina: ricaricandola si perde.
