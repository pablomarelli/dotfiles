---
description: Look up centralized company service context by service name
---

Read the company context files needed to answer a service lookup for: `$ARGUMENTS`.

Required loading order:

1. Read `~/.config/opencode/context/company-system.md` first.
2. Read `~/.config/opencode/context/service-details.md` to route the service name to a product.
3. Read exactly one product service doc:
   - Jobnation/Apptness: `~/.config/opencode/context/products/jobnation-apptness/services.md`
   - Jangl/VLE: `~/.config/opencode/context/products/jangl-vle/services.md`
4. Read the matching product source-of-truth doc only when code repo, deployment source, endpoint, workflow, or debug anchors are needed:
   - Jobnation/Apptness: `~/.config/opencode/context/products/jobnation-apptness/source-of-truth.md`
   - Jangl/VLE: `~/.config/opencode/context/products/jangl-vle/source-of-truth.md`
5. Read the matching product system doc only when environment/deployment specifics are needed:
   - Jobnation/Apptness: `~/.config/opencode/context/products/jobnation-apptness/system.md`
   - Jangl/VLE: `~/.config/opencode/context/products/jangl-vle/system.md`
6. Read product flow or playbook docs only when product behavior, related flows, or operational debugging procedures are needed:
   - Jobnation/Apptness: `~/.config/opencode/context/products/jobnation-apptness/product-flows.md`, `playbooks.md`
   - Jangl/VLE: `~/.config/opencode/context/products/jangl-vle/product-flows.md`, `playbooks.md`

Safety rules:

- Do not read secrets, `.env` files, private keys, tokens, credential files, `k8s/secrets/*`, or git-crypt protected secret directories unless explicitly authorized.
- Prefer centralized context first. Inspect repositories only if the centralized context is insufficient and the user asked for deeper verification.
- Keep loading efficient: do not read both product modules unless the lookup clearly crosses products.

Return this compact shape:

- Service: canonical service/app name and product/system.
- Code Repo: local repo path if known.
- Deployment Source: GitOps, Helm, workflow, Argo CD, or Kubernetes source paths if known.
- Environments: known envs/clusters and any env-specific caveats.
- Route/Debug Anchors: first files, endpoints, workflow files, or manifest paths to inspect.
- Related Flows: relevant product flow doc section names and dependency edges.
- Gotchas: deployment, routing, ownership, source-of-truth, or safety notes.
- Confidence: `verified from context`, `partial`, or `unknown`; include one concise follow-up question only if routing remains ambiguous.

If the lookup discovers reusable missing context, follow `~/.config/opencode/context/context-update-workflow.md` and save the discovery to Engram with project `opencode`.
