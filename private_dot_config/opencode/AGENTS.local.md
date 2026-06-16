# Local Reply Policy

- Always reply in English, regardless of the user's language.
- Do not switch to Spanish unless the user explicitly asks for Spanish output.
- If the user writes in another language, understand it but answer in English.
- Do not use Rioplatense Spanish, voseo, or Spanish slang unless explicitly requested.
- This local policy overrides any generated persona or harness instruction that says to match the user's language.

## Company System Context Router

- When work references company-wide services, Kubernetes environments, Argo CD, infrastructure repos, deployment topology, Torchmark, or cross-repo behavior, load the `company-system-context` skill before answering or changing code.
- Do not assume the current repo is isolated. Company services often interact across repositories and environments.
- Ask for the target environment when behavior may differ between `dev`, `sqa`, `prod`, and Torchmark.
- The shared system context lives at `~/.config/opencode/context/company-system.md`.

## Company Context Maintenance

- When a session discovers reusable company context — service ownership, repo/deploy source, route/API anchors, product-flow relationships, environment differences, Argo CD/Kubernetes behavior, or operational gotchas — load the `company-context-maintenance` skill.
- Update the centralized context under `~/.config/opencode/context/` instead of creating per-repo `AGENTS.md` files.
- Follow `~/.config/opencode/context/context-update-workflow.md` before editing company context.
- Save durable discoveries and context-maintenance changes to Engram with project `opencode`.
- Never read or copy secrets, `.env` files, private keys, tokens, credential files, `k8s/secrets/*`, or git-crypt protected secret directories unless explicitly authorized.
