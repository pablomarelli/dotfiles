---
name: python-good-practices
description: "Trigger: Python code, Python refactor, Python tests, backend Python. Apply FP-first, DDD-aware Python with mandatory tests."
license: Apache-2.0
metadata:
  author: pablo-marelli
  version: "1.0"
---

## Activation Contract

Load this skill when writing, reviewing, refactoring, or testing Python code, especially backend, CLI, automation, service, API, or domain logic.

## Hard Rules

- Tests are mandatory for behavior changes. Bug fixes need regression tests; refactors must keep existing tests passing and add coverage when changed behavior is unprotected.
- Prefer functional core, imperative shell: pure functions for decisions and transformations; side effects at I/O, framework, database, queue, and network boundaries.
- Make dependencies explicit through parameters, constructors, or narrow protocols. Avoid hidden globals, implicit singletons, and ambient mutable state.
- Keep code typed. Add annotations to public functions, domain functions, async boundaries, and non-obvious data structures.
- Raise or return explicit domain errors. Do not swallow exceptions unless the fallback behavior is intentional, tested, and logged.
- Do not introduce architecture ceremony unless it reduces complexity for the current problem.

## Decision Gates

| Situation | Preferred approach |
| --- | --- |
| Business rule or decision | Pure function, value object, or small domain service. |
| I/O, DB, HTTP, queue, filesystem | Imperative adapter at the edge; keep parsing and decisions separate. |
| Real domain complexity | Use DDD naming and boundaries around the business language. |
| Simple script or CRUD | Stay simple; do not add aggregates, repositories, or events by default. |
| Stateful lifecycle or framework requirement | Use a class only when it makes state ownership clearer. |
| Async code | Keep async at I/O boundaries; do not wrap CPU-only pure logic in async. |

## Domain Modeling

- Name modules, functions, values, and tests with the domain language used by the business.
- Keep domain logic independent from FastAPI, Django, Flask, Typer, SQLAlchemy, Pydantic, Celery, HTTP clients, and storage models.
- Treat ORM models, request schemas, response schemas, and third-party payloads as boundary types unless the project already uses them as domain objects.
- Use DDD tactically when business rules are meaningful: entities for identity and lifecycle, value objects for validated concepts, domain services for rules spanning objects.
- Avoid anemic code where important rules are scattered across handlers, serializers, jobs, or persistence callbacks.

## Testing Contract

1. Identify the smallest behavior boundary that proves the change.
2. Write or update tests next to the behavior: unit tests for pure logic, integration tests for adapters, regression tests for bugs.
3. Test observable behavior, errors, edge cases, and side effects. Avoid tests that only mirror implementation.
4. Prefer deterministic fixtures, local fakes, dependency injection, and temporary resources over real external services.
5. Run the narrow relevant tests first, then the broader suite when practical. If tests cannot run, report the exact blocker and manual verification performed.

## Execution Steps

1. Locate the business rule, side effect boundary, and existing test pattern before editing.
2. Move decisions toward pure, typed functions when it reduces coupling.
3. Keep framework handlers thin: validate input, call application/domain logic, map output.
4. Keep persistence and API clients behind small adapters; do not leak third-party payload shapes deep into domain code.
5. Add or update tests in the same work unit as the code change.
6. Run formatting, linting, type checks, and tests according to the repository's configured tools.

## Output Contract

Report the files changed, behavior covered by tests, commands run, any verification gaps, and any architecture tradeoff made between simple Python, FP, and DDD.

## References

- No bundled references. Follow the target repository's configured Python tools and conventions first.
