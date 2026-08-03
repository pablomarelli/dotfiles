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

## Stack

- Lets use modern Python tooling and follow pep conventions.
- UV for package and project management
- FastAPI for backend APIs
- Pydantic for schemas and validations
- OpenAPI specs
- SQLModel for database
- Alembic for migrations
- Typer for CLI tools
- pytest for testing
- Docker
- pyproject.toml for management
- Taskfile in bash with common used commands for the project

## Rules

- Keep code as simple as possible
- Prefer functional programming over OOP except for data entities like models, schemas, config, etc
- Simple primitive typing like golang
- Avoid validation/normalization except for external layers. That should belong to serializers, schemas and models.

## Decision Gates

| Situation | Preferred approach |
| --- | --- |
| Business rule or decision | Pure function, value object, or small domain service. |
| I/O, DB, HTTP, queue, filesystem | Imperative adapter at the edge; keep parsing and decisions separate. |
| Real domain complexity | Use DDD naming and boundaries around the business language. |
| Simple script or CRUD | Stay simple; do not add aggregates, repositories, or events by default. |
| Stateful lifecycle or framework requirement | Use a class only when it makes state ownership clearer. |
| Async code | Keep async at I/O boundaries; do not wrap CPU-only pure logic in async. |


## Testing

- Only test our code, isolate small pieces and test that, our code should be structured in a way we can use fixtures and ignore mocking as far as we can
- Pure async functional programming tests.
- Use parametrized fixtures
