// Sends ntfy push notifications when an OpenCode session finishes, fails, or needs input.
// Reads OPENCODE_NTFY_URL / OPENCODE_NTFY_TOKEN from the environment or ~/.config/opencode/ntfy.env.

import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { basename } from "node:path"

const ENV_FILE = `${homedir()}/.config/opencode/ntfy.env`

// The service loads one plugin instance per location, and every instance receives
// the server-global event stream. Share one record of handled events per process
// so each event produces at most one notification.
const shared = (globalThis[Symbol.for("opencode.ntfy")] ??= { handled: new Map() })
const HANDLED_TTL_MS = 10 * 60 * 1000

const NOTIFY_EVENTS = new Set([
  "session.execution.succeeded",
  "session.execution.failed",
  "permission.asked",
  "form.created",
])

function claim(eventID) {
  const now = Date.now()
  for (const [id, at] of shared.handled) {
    if (now - at < HANDLED_TTL_MS) break
    shared.handled.delete(id)
  }
  if (shared.handled.has(eventID)) return false
  shared.handled.set(eventID, now)
  return true
}

function readEnvFile() {
  const config = {}
  let content
  try {
    content = readFileSync(ENV_FILE, "utf8")
  } catch {
    return config
  }
  for (const line of content.split("\n")) {
    const match = line.match(/^\s*(?:export\s+)?([A-Z0-9_]+)=(.*)$/)
    if (!match) continue
    const value = match[2].trim().replace(/^(['"])(.*)\1$/, "$2")
    if (match[1] === "OPENCODE_NTFY_URL") config.url = value
    if (match[1] === "OPENCODE_NTFY_TOKEN") config.token = value
  }
  return config
}

function loadConfig() {
  const file = readEnvFile()
  return {
    url: process.env.OPENCODE_NTFY_URL || file.url,
    token: process.env.OPENCODE_NTFY_TOKEN || file.token,
  }
}

async function publish({ title, message, tags, priority = "default" }) {
  const config = loadConfig()
  if (!config.url) return

  const headers = { Title: title, Priority: priority, Tags: tags }
  if (config.token) headers.Authorization = `Bearer ${config.token}`

  try {
    await fetch(config.url, {
      method: "POST",
      headers,
      body: message,
      signal: AbortSignal.timeout(5000),
    })
  } catch {
    // Notifications are best-effort and must never disturb OpenCode.
  }
}

async function sessionInfo(ctx, sessionID) {
  try {
    const result = await ctx.session.get({ sessionID })
    return result?.data ?? result
  } catch {
    return undefined
  }
}

function describe(session) {
  const directory = session?.location?.directory
  return {
    project: directory ? basename(directory) : "opencode",
    title: session?.title,
  }
}

function body(lines) {
  return lines.filter(Boolean).join("\n")
}

async function handle(ctx, event) {
  const data = event.data ?? {}

  switch (event.type) {
    case "session.execution.succeeded":
    case "session.execution.failed": {
      const session = await sessionInfo(ctx, data.sessionID)
      // Subagent runs report back to their parent; only the root run is worth a ping.
      if (!session || session.parentID) return
      const { project, title } = describe(session)
      const failed = event.type === "session.execution.failed"
      await publish({
        title: failed ? `OpenCode failed - ${project}` : `OpenCode finished - ${project}`,
        message: body([title, failed ? data.error?.message : undefined]) || data.sessionID,
        tags: failed ? "computer,x" : "computer,white_check_mark",
        priority: failed ? "high" : "default",
      })
      return
    }
    case "permission.asked":
    case "form.created": {
      const sessionID = event.type === "form.created" ? data.form?.sessionID : data.sessionID
      const { project, title } = describe(await sessionInfo(ctx, sessionID))
      const detail =
        event.type === "form.created"
          ? data.form?.title
          : `Permission: ${data.action}${data.resources?.length ? ` ${data.resources.join(", ")}` : ""}`
      await publish({
        title: `OpenCode needs input - ${project}`,
        message: body([title, detail]) || "Waiting for your answer",
        tags: "computer,raising_hand",
        priority: "high",
      })
      return
    }
  }
}

export default {
  id: "personal.ntfy",
  setup(ctx) {
    const controller = new AbortController()

    void (async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        if (!NOTIFY_EVENTS.has(event?.type) || !event.id || !claim(event.id)) continue
        void handle(ctx, event).catch(() => {})
      }
    })().catch(() => {})

    return () => controller.abort()
  },
}
