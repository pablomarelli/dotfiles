import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { homedir } from "node:os"

type NtfyConfig = {
  url?: string
  token?: string
}

function parseEnvFile(path: string): NtfyConfig {
  try {
    const config: NtfyConfig = {}
    const content = readFileSync(path, "utf8")

    for (const line of content.split("\n")) {
      const match = line.match(/^\s*(?:export\s+)?([A-Z0-9_]+)=(.*)\s*$/)
      if (!match) continue

      const key = match[1]
      const value = match[2].trim().replace(/^['"]|['"]$/g, "")

      if (key === "OPENCODE_NTFY_URL") config.url = value
      if (key === "OPENCODE_NTFY_TOKEN") config.token = value
    }

    return config
  } catch {
    return {}
  }
}

function loadConfig(): NtfyConfig {
  const fileConfig = parseEnvFile(`${homedir()}/.config/opencode/ntfy.env`)

  return {
    url: process.env.OPENCODE_NTFY_URL || fileConfig.url,
    token: process.env.OPENCODE_NTFY_TOKEN || fileConfig.token,
  }
}

function tmuxLocation(): string {
  const pane = process.env.TMUX_PANE
  if (!pane) return ""

  try {
    return execFileSync(
      "tmux",
      [
        "display-message",
        "-p",
        "-t",
        pane,
        "#{session_name}:#{window_name}",
      ],
      { encoding: "utf8", timeout: 500 }
    ).trim()
  } catch {
    return ""
  }
}

async function publish(message: string): Promise<void> {
  const config = loadConfig()
  if (!config.url) return

  const headers: Record<string, string> = {
    Title: "opencode response finished",
    Priority: "default",
    Tags: "computer,white_check_mark",
  }

  if (config.token) {
    headers.Authorization = `Bearer ${config.token}`
  }

  try {
    await fetch(config.url, {
      method: "POST",
      headers,
      body: message,
      signal: AbortSignal.timeout(2000),
    })
  } catch {
    // Notifications are best-effort and must never block opencode.
  }
}

export default (async () => {
  const busySessions = new Set<string>()

  async function notifyFinished(sessionID: string): Promise<void> {
    if (!busySessions.has(sessionID)) return
    busySessions.delete(sessionID)

    const tmux = tmuxLocation()

    await publish(
      [
        "opencode finished responding.",
        tmux ? `Tmux: ${tmux}` : "",
        `Session: ${sessionID}`,
      ]
        .filter(Boolean)
        .join("\n")
    )
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.status") {
        const properties = event.properties as {
          sessionID?: string
          status?: { type?: string }
        }

        if (!properties.sessionID) return

        if (properties.status?.type === "busy") {
          busySessions.add(properties.sessionID)
          return
        }

        if (properties.status?.type === "idle") {
          await notifyFinished(properties.sessionID)
        }
      }

      if (event.type === "session.idle") {
        const properties = event.properties as { sessionID?: string }
        if (properties.sessionID) {
          await notifyFinished(properties.sessionID)
        }
      }
    },
  }
}) satisfies Plugin
