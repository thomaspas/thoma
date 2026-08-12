export const DEFAULT_SETTINGS = {
  apiUrl: "http://127.0.0.1:8000",
  email: "ye@evox3.local",
  password: "evox3-local-12"
}

export async function loadSettings() {
  const stored = await chrome.storage.sync.get(DEFAULT_SETTINGS)
  return {
    apiUrl: stored.apiUrl || DEFAULT_SETTINGS.apiUrl,
    email: stored.email || DEFAULT_SETTINGS.email,
    password: stored.password || DEFAULT_SETTINGS.password
  }
}

export async function saveSettings(settings) {
  await chrome.storage.sync.set(settings)
}

export async function login(settings) {
  const base = settings.apiUrl.replace(/\/$/, "")
  const res = await fetch(`${base}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: settings.email, password: settings.password })
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`login HTTP ${res.status}: ${text.slice(0, 200)}`)
  }
  const body = await res.json()
  if (!body.access_token) {
    throw new Error("login response missing access_token")
  }
  return body.access_token
}

export async function uploadMarkdown(settings, markdown, title) {
  const token = await login(settings)
  const base = settings.apiUrl.replace(/\/$/, "")
  const blob = new Blob([markdown], { type: "text/markdown" })
  const form = new FormData()
  form.append("file", blob, "capture.md")
  form.append("title", title)
  const res = await fetch(`${base}/documents/upload`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: form
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`upload HTTP ${res.status}: ${text.slice(0, 200)}`)
  }
  return res.json()
}

export function pageToMarkdown(title, url, bodyText) {
  const trimmed = bodyText.replace(/\s+/g, " ").trim().slice(0, 50000)
  return `# ${title}\n\nSource: ${url}\n\nCaptured: ${new Date().toISOString()}\n\n${trimmed}\n`
}
