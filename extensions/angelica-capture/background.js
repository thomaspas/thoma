import { loadSettings, pageToMarkdown, uploadMarkdown } from "./lib/api.js"

async function notify(title, message) {
  await chrome.notifications.create({
    type: "basic",
    iconUrl: "assets/icon.png",
    title,
    message
  })
}

async function captureActiveTab(mode, selection) {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
  if (!tab?.id || !tab.url || tab.url.startsWith("chrome://")) {
    await notify("ANGELICA Capture", "Cannot capture this tab")
    return
  }

  let title = tab.title || "Untitled"
  const url = tab.url
  let bodyText = ""

  if (mode === "selection" && selection) {
    bodyText = selection
    title = `Selection: ${title}`
  } else {
    const [{ result }] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => {
        const article = document.querySelector("article")
        const main = document.querySelector("main")
        const root = article || main || document.body
        return (root.innerText || document.body.innerText || "").trim()
      }
    })
    bodyText = result || ""
  }

  const settings = await loadSettings()
  const markdown = pageToMarkdown(title, url, bodyText)
  const { document_id } = await uploadMarkdown(settings, markdown, title.slice(0, 200))
  await notify("ANGELICA Capture", `Uploaded document_id=${document_id}`)
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "angelica-capture-page",
    title: "Capture page to ANGELICA",
    contexts: ["page"]
  })
  chrome.contextMenus.create({
    id: "angelica-capture-selection",
    title: "Capture selection to ANGELICA",
    contexts: ["selection"]
  })
})

chrome.contextMenus.onClicked.addListener(async (info) => {
  try {
    if (info.menuItemId === "angelica-capture-page") {
      await captureActiveTab("page")
      return
    }
    if (info.menuItemId === "angelica-capture-selection" && info.selectionText) {
      const [active] = await chrome.tabs.query({ active: true, currentWindow: true })
      const settings = await loadSettings()
      const title = `Selection: ${active?.title || "page"}`
      const url = active?.url || ""
      const markdown = pageToMarkdown(title, url, info.selectionText)
      const { document_id } = await uploadMarkdown(settings, markdown, title.slice(0, 200))
      await notify("ANGELICA Capture", `Uploaded selection document_id=${document_id}`)
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    await notify("ANGELICA Capture failed", msg.slice(0, 240))
    console.error("ANGELICA capture failed:", err)
  }
})

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "capture-page") {
    captureActiveTab("page")
      .then(() => sendResponse({ ok: true }))
      .catch((err) => sendResponse({ ok: false, error: String(err) }))
    return true
  }
  return false
})
