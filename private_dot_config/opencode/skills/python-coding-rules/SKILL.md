---
name: python-coding-rules
description: "Trigger: Python service, backend, API, worker, CLI, refactor, tests. Build small services with explicit boundaries and shared workflows."
license: Apache-2.0
metadata:
  author: "pablomarelli"
  version: "2.0"
---

## Activation Contract

Load this skill when designing, writing, reviewing, refactoring, or testing Python services, APIs, workers, CLIs, or automation.

## Hard Rules

- Read `references/service-concepts.md` before deciding project structure.
- Keep entry points and transports thin: parse, authorize, delegate, translate.
- Put each business workflow in one plainly named function before extracting abstractions.
- Keep I/O in typed adapters at the edge. Inject adapters and settings into workflows.
- Instantiate settings and resources at the composition root, never at import time.
- Use classes for data, adapter state, or framework lifecycle only. Prefer functions for decisions and workflows.
- Normalize and validate external data only at boundaries.
- Never let persistence models perform network I/O.
- Translate expected errors once at each transport boundary. Do not expose unexpected exception text.
- Do not create registries, base classes, repositories, or generic utilities before repeated concrete use proves the need.

## Decision Gates

| Situation | Use |
| --- | --- |
| HTTP API | FastAPI, Pydantic, OpenAPI |
| SQL persistence | SQLModel and Alembic |
| CLI | Typer calling the same workflows as the API |
| Blocking SDK in async code | `asyncio.to_thread` |
| Concurrent I/O | `TaskGroup`, `gather`, timeout, and bounded fan-out |
| Simple CRUD or script | Flat modules; no DDD ceremony |
| Real domain language and rules | Domain-named functions, values, and boundaries |

## Execution Steps

1. Name the service's principal workflows.
2. Identify inbound transports and outbound systems.
3. Design the thinnest module tree that makes those boundaries visible.
4. Implement one readable top-to-bottom workflow before extracting shared machinery.
5. Test through the real entry point, then add focused workflow and adapter tests.
6. Run Ruff, type checks, pytest, and an end-to-end smoke path.

## Output Contract

Explain the workflows, boundaries, resource ownership, error mapping, and why every abstraction exists.

## References

- `references/service-concepts.md` - architecture and code-shape rules derived from `jangl-call-center`.
