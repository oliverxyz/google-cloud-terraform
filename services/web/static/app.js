"use strict";

const STATUS_REFRESH_MS = 10000;
const byId = (id) => document.getElementById(id);

async function refreshStatus() {
  const list = byId("status");
  const note = byId("status-note");
  try {
    const response = await fetch("/status");
    if (!response.ok) throw new Error(String(response.status));
    const { services } = await response.json();
    list.replaceChildren(
      ...services.map(({ name, status }) => {
        const item = document.createElement("li");
        item.className = status;
        item.textContent = `${name}: ${status}`;
        return item;
      }),
    );
    note.textContent = `Updated ${new Date().toLocaleTimeString()}`;
  } catch {
    note.textContent = "Could not load the status.";
  }
}

// Server responses are shown as text, never as HTML.
async function send(method, path, body) {
  const headers = {};
  const token = byId("token").value.trim();
  if (token) headers.Authorization = `Bearer ${token}`;
  const options = { method, headers };
  if (method === "POST") {
    headers["Content-Type"] = "application/json";
    options.body = JSON.stringify(body ?? {});
  }
  byId("response-status").textContent = `${method} ${path}: waiting…`;
  byId("response").textContent = "";
  try {
    const response = await fetch(path, options);
    const text = await response.text();
    byId("response-status").textContent = `${method} ${path}: HTTP ${response.status}`;
    byId("response").textContent = pretty(text);
    return response.ok ? JSON.parse(text) : null;
  } catch {
    byId("response-status").textContent = `${method} ${path}: request failed`;
    return null;
  }
}

function pretty(text) {
  try {
    return JSON.stringify(JSON.parse(text), null, 2);
  } catch {
    return text;
  }
}

byId("create-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const created = await send("POST", "/api/documents", {
    title: byId("title").value,
    content: byId("content").value,
    simulate_failure: byId("simulate-failure").checked,
  });
  if (created?.id) byId("document-id").value = created.id;
});

const documentPath = () => `/api/documents/${encodeURIComponent(byId("document-id").value.trim())}`;

byId("document-form").addEventListener("submit", (event) => {
  event.preventDefault();
  send("GET", documentPath());
});

byId("add-revision").addEventListener("click", () => {
  if (!byId("document-form").reportValidity()) return;
  send("POST", `${documentPath()}/revisions`, { content: byId("revision").value });
});

byId("report").addEventListener("click", () => send("POST", "/api/reports"));

refreshStatus();
setInterval(refreshStatus, STATUS_REFRESH_MS);
