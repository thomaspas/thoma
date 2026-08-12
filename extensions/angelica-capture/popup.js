import { DEFAULT_SETTINGS, loadSettings, saveSettings } from "./lib/api.js"

const apiUrl = document.getElementById("apiUrl")
const email = document.getElementById("email")
const password = document.getElementById("password")
const status = document.getElementById("status")
const saveBtn = document.getElementById("saveBtn")
const captureBtn = document.getElementById("captureBtn")

function setStatus(text) {
  status.textContent = text
}

async function init() {
  const settings = await loadSettings()
  apiUrl.value = settings.apiUrl
  email.value = settings.email
  password.value = settings.password
}

saveBtn.addEventListener("click", async () => {
  saveBtn.disabled = true
  setStatus("")
  try {
    await saveSettings({
      apiUrl: apiUrl.value.trim(),
      email: email.value.trim(),
      password: password.value
    })
    setStatus("Saved")
  } catch (err) {
    setStatus(err instanceof Error ? err.message : String(err))
  } finally {
    saveBtn.disabled = false
  }
})

captureBtn.addEventListener("click", async () => {
  captureBtn.disabled = true
  setStatus("")
  try {
    await saveSettings({
      apiUrl: apiUrl.value.trim(),
      email: email.value.trim(),
      password: password.value
    })
    const res = await chrome.runtime.sendMessage({ type: "capture-page" })
    setStatus(res?.ok ? "Capture started — check notification" : res?.error || "Failed")
  } catch (err) {
    setStatus(err instanceof Error ? err.message : String(err))
  } finally {
    captureBtn.disabled = false
  }
})

init().catch((err) => setStatus(String(err)))
