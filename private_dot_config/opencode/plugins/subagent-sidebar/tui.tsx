import { Plugin, usePlugin } from "@opencode/plugin/tui"
import type { LocationRef, SessionInfo, ShellInfo } from "@opencode/client"
import { createMemo, createSignal, For, onCleanup, Show } from "solid-js"

interface Entry {
  sessionID: string
  agent: string
  title: string
  running: boolean
  current: boolean
  prefix: string
}

function titlecase(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

// Children of the current session's root, in tree order with box-drawing prefixes.
function family(sessions: readonly SessionInfo[], sessionID: string) {
  const byID = new Map(sessions.map((session) => [session.id, session]))
  const current = byID.get(sessionID)
  if (!current) return []

  const children = new Map<string, SessionInfo[]>()
  for (const session of sessions) {
    if (!session.parentID) continue
    const group = children.get(session.parentID)
    if (group) group.push(session)
    else children.set(session.parentID, [session])
  }

  function root(session: SessionInfo): SessionInfo {
    const parent = session.parentID ? byID.get(session.parentID) : undefined
    return parent ? root(parent) : session
  }

  function walk(parentID: string, ancestors: boolean[]): Array<{ session: SessionInfo; prefix: string }> {
    const group = children.get(parentID) ?? []
    return group.flatMap((session, index) => {
      const last = index === group.length - 1
      const prefix =
        ancestors.length === 0
          ? ""
          : ancestors
              .slice(1)
              .map((ancestor) => (ancestor ? "   " : "│  "))
              .join("") + (last ? "└─ " : "├─ ")
      return [{ session, prefix }, ...walk(session.id, [...ancestors, last])]
    })
  }

  return walk(root(current).id, [])
}

function SidebarSubagents(props: { sessionID: string }) {
  const context = usePlugin()
  const theme = context.theme
  const [view, updateView] = context.storage.store("view", { initial: { open: true } })

  const entries = createMemo<Entry[]>(() =>
    family(context.data.session.list(), props.sessionID).map(({ session, prefix }) => {
      const raw = session.title ?? session.id
      const match = raw.match(/@(\w+) subagent/)
      return {
        sessionID: session.id,
        agent: session.agent ? titlecase(session.agent) : match ? titlecase(match[1]) : "Subagent",
        title: match ? raw.replace(match[0], "").trim() || raw : raw,
        running: context.data.session.status(session.id) === "running",
        current: session.id === props.sessionID,
        prefix,
      }
    }),
  )
  const running = createMemo(() => entries().filter((entry) => entry.running).length)

  return (
    <box>
      <box
        flexDirection="row"
        gap={1}
        onMouseDown={() => {
          void updateView((draft) => {
            draft.open = !draft.open
          }).catch((error) => console.error("Failed to persist subagent sidebar state", error))
        }}
      >
        <text fg={theme.text.base}>{view.open ? "▼" : "▶"}</text>
        <text fg={theme.text.base}>
          <b>Subagents</b>
          <Show when={entries().length > 0}>
            <span style={{ fg: theme.text.muted }}>
              {" "}
              ({running()} running, {entries().length} total)
            </span>
          </Show>
        </text>
      </box>
      <Show when={view.open}>
        <Show when={entries().length > 0} fallback={<text fg={theme.text.muted}>  No subagents running</text>}>
          <For each={entries()}>
            {(entry) => (
              <box
                flexDirection="row"
                paddingLeft={2}
                onMouseUp={() => context.ui.router.navigate({ type: "session", sessionID: entry.sessionID })}
              >
                <text fg={entry.current || entry.running ? theme.text.base : theme.text.muted} wrapMode="none">
                  <span style={{ fg: entry.running ? theme.text.feedback.success.base : theme.text.muted }}>
                    {entry.running ? "● " : "○ "}
                  </span>
                  {entry.prefix}
                  {entry.current ? <b>{entry.agent}</b> : entry.agent}: {entry.title}
                </text>
              </box>
            )}
          </For>
        </Show>
      </Show>
    </box>
  )
}

function elapsed(started: number, now: number) {
  const seconds = Math.max(0, Math.floor((now - started) / 1000))
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m ${seconds % 60}s`
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`
}

// Running shell commands started by the current session or any session in its family. The host only keeps
// in-flight shells, so finished commands drop out on their own.
function SidebarShells(props: { sessionID: string }) {
  const context = usePlugin()
  const theme = context.theme
  const [view, updateView] = context.storage.store("shells", { initial: { open: true } })
  const [now, setNow] = createSignal(Date.now())
  const timer = setInterval(() => setNow(Date.now()), 1000)
  onCleanup(() => clearInterval(timer))

  const shells = createMemo(() => {
    const session = context.data.session.get(props.sessionID)
    const ids = new Set(context.data.session.family(props.sessionID))
    const seen = new Set<string>()
    return [...context.data.shell.list(session?.location), ...context.data.shell.list()]
      .filter((shell) => {
        if (seen.has(shell.id)) return false
        seen.add(shell.id)
        const owner = shell.metadata.sessionID
        return shell.status === "running" && (typeof owner !== "string" || ids.has(owner))
      })
      .sort((a, b) => a.time.started - b.time.started)
  })

  async function showOutput(shell: ShellInfo & { readonly location?: LocationRef }) {
    const first = shell.command.split("\n", 1)[0]
    const result = await context.client.api.shell
      .output({ id: shell.id, location: { directory: shell.location?.directory } })
      .catch((error: unknown) => ({ error }))
    if ("error" in result) {
      const reason = result.error instanceof Error ? result.error.message : String(result.error)
      await context.ui.dialog.alert({ title: first, message: `Could not read output: ${reason}` })
      return
    }
    const body = result.data.output.trim() || "(no output yet)"
    await context.ui.dialog.alert({ title: first, message: result.data.truncated ? `…\n${body}` : body })
  }

  return (
    <box>
      <box
        flexDirection="row"
        gap={1}
        onMouseDown={() => {
          void updateView((draft) => {
            draft.open = !draft.open
          }).catch((error) => console.error("Failed to persist shell sidebar state", error))
        }}
      >
        <text fg={theme.text.base}>{view.open ? "▼" : "▶"}</text>
        <text fg={theme.text.base}>
          <b>Shells</b>
          <Show when={shells().length > 0}>
            <span style={{ fg: theme.text.muted }}> ({shells().length} running)</span>
          </Show>
        </text>
      </box>
      <Show when={view.open}>
        <Show when={shells().length > 0} fallback={<text fg={theme.text.muted}>  No background shell running</text>}>
          <For each={shells()}>
            {(shell) => (
              <box flexDirection="row" paddingLeft={2} gap={1} onMouseUp={() => void showOutput(shell)}>
                <box flexGrow={1} minWidth={0}>
                  <text fg={theme.text.base} wrapMode="none">
                    <span style={{ fg: theme.text.feedback.success.base }}>● </span>
                    {shell.command.split("\n", 1)[0]}
                  </text>
                </box>
                <text fg={theme.text.muted} wrapMode="none">
                  {shell.metadata.background === true ? "bg " : ""}
                  {elapsed(shell.time.started, now())}
                </text>
              </box>
            )}
          </For>
        </Show>
      </Show>
    </box>
  )
}

export default Plugin.define({
  id: "pablo.sidebar.subagents",
  setup(context) {
    const stopSubagents = context.ui.slot({
      append: "sidebar.content",
      render: (props) => <SidebarSubagents sessionID={props.sessionID} />,
    })
    const stopShells = context.ui.slot({
      append: "sidebar.content",
      render: (props) => <SidebarShells sessionID={props.sessionID} />,
    })
    return () => {
      stopSubagents()
      stopShells()
    }
  },
})
