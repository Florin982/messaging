<script setup>
import { computed, nextTick, reactive, ref, watch } from "vue";

// In sviluppo usa il server locale; compilata, si collega a chi l'ha servita.
const SERVER_URL =
  import.meta.env.VITE_SERVER_URL ||
  (import.meta.env.DEV
    ? "ws://localhost:8765/admin"
    : `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/admin`);
const ALL = null; // chiave della chat "Tutti"

let ws = null;

const loggedIn = ref(false);
const loginError = ref("");
const username = ref("");
const password = ref("");

const guests = ref([]);
const current = ref(undefined); // chat aperta: nome del guest, ALL, o undefined se nessuna
const chats = reactive(new Map()); // chat -> [{ text, mine }]
const unread = reactive(new Map()); // guest -> messaggi non letti
const draft = ref("");

const messagesBox = ref(null);
const textInput = ref(null);

const isOpen = computed(() => current.value !== undefined);
const canSend = computed(
  () => isOpen.value && (current.value === ALL || guests.value.includes(current.value)),
);
const messages = computed(() => chats.get(current.value) ?? []);
const title = computed(() => {
  if (!isOpen.value) return "Seleziona un utente";
  if (current.value === ALL) return "Tutti";
  return canSend.value ? current.value : `${current.value} (disconnesso)`;
});

watch(
  () => [current.value, messages.value.length],
  async () => {
    await nextTick();
    if (messagesBox.value) messagesBox.value.scrollTop = messagesBox.value.scrollHeight;
  },
);

function addMessage(chat, message) {
  if (!chats.has(chat)) chats.set(chat, []);
  chats.get(chat).push(message);
}

async function openChat(chat) {
  current.value = chat;
  unread.delete(chat);
  await nextTick();
  textInput.value?.focus();
}

function onMessage(event) {
  const data = JSON.parse(event.data);

  if (data.type === "login_ok") {
    loggedIn.value = true;
  } else if (data.type === "login_error") {
    loginError.value = data.text;
    ws.close();
  } else if (data.type === "guests") {
    guests.value = data.guests;
  } else if (data.type === "message") {
    addMessage(data.from, { text: data.text, mine: false });
    if (data.from !== current.value) {
      unread.set(data.from, (unread.get(data.from) ?? 0) + 1);
    }
  } else if (data.type === "error") {
    alert(data.text);
  }
}

function login() {
  const credentials = JSON.stringify({ username: username.value, password: password.value });
  password.value = "";
  loginError.value = "";

  ws = new WebSocket(SERVER_URL);
  ws.onopen = () => ws.send(credentials);
  ws.onmessage = onMessage;
  ws.onclose = () => {
    if (loggedIn.value) {
      loggedIn.value = false;
      loginError.value = "Connessione con il server persa";
    } else if (!loginError.value) {
      loginError.value = "Server non raggiungibile";
    }
  };
}

function send() {
  const text = draft.value;
  if (!text) return;
  ws.send(JSON.stringify({ to: current.value, text }));
  addMessage(current.value, { text, mine: true });
  draft.value = "";
}
</script>

<template>
  <form v-if="!loggedIn" class="login" @submit.prevent="login">
    <h1>Accesso admin</h1>
    <label>Utente <input v-model="username" autocomplete="username" required autofocus></label>
    <label>
      Password
      <input v-model="password" type="password" autocomplete="current-password" required>
    </label>
    <button>Accedi</button>
    <p class="error" role="alert">{{ loginError }}</p>
  </form>

  <main v-else class="app">
    <aside class="sidebar">
      <h2>Utenti connessi</h2>
      <button class="contact" :class="{ active: current === ALL }" @click="openChat(ALL)">
        Tutti
      </button>
      <ul>
        <li v-for="name in guests" :key="name">
          <button class="contact" :class="{ active: current === name }" @click="openChat(name)">
            {{ name }}
            <span v-if="unread.get(name)" class="badge">{{ unread.get(name) }}</span>
          </button>
        </li>
      </ul>
      <p v-if="!guests.length" class="hint">Nessun utente connesso</p>
    </aside>

    <section class="chat">
      <header class="chat-title">{{ title }}</header>
      <div ref="messagesBox" class="messages" aria-live="polite">
        <div
          v-for="(message, index) in messages"
          :key="index"
          class="message"
          :class="{ mine: message.mine }"
        >
          {{ message.text }}
        </div>
      </div>
      <form class="composer" @submit.prevent="send">
        <input
          ref="textInput"
          v-model="draft"
          placeholder="Scrivi un messaggio..."
          autocomplete="off"
          aria-label="Messaggio"
          :disabled="!canSend"
        >
        <button :disabled="!canSend">Invia</button>
      </form>
    </section>
  </main>
</template>
