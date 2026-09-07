# Small Python Service Concepts

This guide extracts the strongest service-design ideas visible in Reginald Beakes's work on `jangl-call-center`. It is not a template and does not preserve that repository's accidental complexity. Use the concepts to shape a new service around its actual workflows.

## The Synthesis

A Python service is a small composition of workflows and boundaries:

```text
configuration + resource lifecycle
               |
               v
HTTP / CLI / worker -> workflow -> outbound adapter -> external system
       |                  |
       v                  v
 transport models     domain values
```

The architecture should make that flow obvious from filenames and function calls. Framework code stays at the edges. Business sequencing stays in a transport-neutral workflow. External SDK and protocol details stay in adapters.

The target is not the fewest files or lines at any cost. It is the least code that states the service's behavior, ownership, and failure modes clearly.

## 1. Start With Workflows, Not Layers

Before creating directories, write down the verbs the service owns, such as:

- transfer a call
- ingest a record
- synchronize agents
- purchase a phone number
- process one queued message

Each principal verb should become one plainly named workflow function whose control flow can be read top-to-bottom. Organize modules around domain capabilities or external boundaries only when doing so makes those workflows easier to find.

Do not begin with `BaseService`, repositories, factories, registries, managers, or a generic application framework. Extract a shared mechanism only after multiple real workflows need the same behavior.

## 2. Keep Inbound Adapters Thin

HTTP routes, CLI commands, and worker loops are inbound adapters. They should only:

1. Parse and validate transport input.
2. Authenticate or authorize when required.
3. Obtain dependencies.
4. Call one workflow.
5. Translate its result or expected errors into transport semantics.

An entry point should not traverse third-party SDK objects, coordinate several remote calls, contain business choices, or construct persistence queries. If a route is difficult to test without mocking its internals, it probably owns too much behavior.

`app.py` and command launchers should expose factories or invoke them. They should contain no service behavior.

## 3. Make Outbound I/O Explicit

Put HTTP clients, SDK calls, SQL access, queues, and filesystems behind small adapters named after the external capability. Expose only operations the workflows actually use.

Prefer this:

```python
async def transfer_call(command: TransferCall, contacts: Contacts, calls: Calls) -> TransferResult:
    record = await contacts.get_record(command.record_id)
    return await calls.transfer(record.phone, command.destination)
```

over a route that understands HTTP payloads, ContactSpace response dictionaries, Twilio conference objects, and downstream status codes simultaneously.

Use protocols when multiple implementations or test fakes genuinely benefit from a structural contract. Do not wrap every library merely to satisfy a layering diagram.

## 4. Compose Dependencies Once

The application factory is the composition root. It should:

- load typed settings
- construct resource-owning clients
- wire adapters into workflows or transport dependencies
- register routes, commands, or message handlers explicitly
- close resources in reverse order

Do not instantiate settings, database engines, clients, or mutable registries during module import. Import-time state makes tests order-dependent and hides resource ownership.

Use one `asynccontextmanager`, commonly with `AsyncExitStack`, for shared lifecycle. API, CLI, and worker processes may enter the same resource context, but each process owns its own instances.

## 5. Keep Models Honest

Use distinct model roles when the boundaries differ:

- transport models describe HTTP, message, or CLI contracts
- domain values express concepts and invariants used by workflows
- persistence models describe stored state
- adapter DTOs describe third-party payloads when typing adds value

Do not reuse a SQL model as an API response merely to avoid a small schema. Do not make a persistence model call an external API. Do not inherit a data schema from an HTTP response class.

External aliases and normalization belong at the inbound adapter. Internal names should remain idiomatic and stable.

Use dictionaries only for genuinely open data. If downstream code relies on known fields, model those fields.

## 6. Define Failure Ownership

Errors move inward as meaningful outcomes and outward as transport responses:

```text
SDK/HTTP/database error
        -> adapter error
        -> workflow/domain outcome
        -> HTTP status, CLI exit, or worker retry policy
```

Adapters should call protocol checks such as `raise_for_status()` and translate known external failures. Workflows may add business meaning. Routes and commands translate expected failures once.

Never return raw exception types or messages to clients. Unexpected exceptions should preserve traceback context, reach logging and error reporting, and cause the correct process-level failure.

## 7. Treat Async as an I/O Property

Keep pure decisions synchronous. Use async where work waits on I/O.

- Use `asyncio.to_thread` for blocking SDK calls.
- Use `TaskGroup` or `gather` for independent I/O.
- Bound fan-out with a semaphore or batching when cardinality grows.
- Put deadlines around external work.
- Preserve cancellation and clean up resources.

Do not build custom concurrency primitives around standard `asyncio` without a measured, documented need.

Workers need an explicit cancellation-aware loop, per-message processing, acknowledgment only after success, and a stated retry or dead-letter policy. Fatal startup and processing failures must not be swallowed as successful exits.

## 8. Test Behavior at Three Distances

Begin with an end-to-end path matching what a user or caller experiences. Then keep the suite economical:

1. Entry-point tests invoke the real FastAPI app, Typer command, or message handler and fake only external boundaries.
2. Workflow tests use simple in-memory fakes and assert decisions and sequencing.
3. Adapter contract tests exercise serialization, status handling, and error translation against HTTP mocks, test databases, or SDK fakes.

Assert transformed requests and observable results, not only that a mock was called. Avoid patching internal functions when dependency injection can provide a fake boundary. Commented tests are dead code.

## 9. Control the Amount of Code

Use these as review signals, not mechanical limits:

- A route or command commonly needs 10-30 lines.
- A principal workflow commonly needs 20-60 lines.
- An adapter should expose only a handful of operations currently used.
- A module should have one clear reason to open it.
- Infrastructure should not outweigh the core workflows it supports.

When code grows, first split by workflow or external boundary. Do not split merely to make files shorter. Keep a workflow in one function until extraction names a real concept, removes real duplication, or isolates I/O.

## 10. Default Project Shape

Start flatter than this and add directories only as needed:

```text
project_name/
  api.py              # FastAPI factory and route registration
  cli.py              # Typer factory
  worker.py           # queue loop and message boundary
  config.py           # typed settings factory
  lifecycle.py        # resource ownership
  models.py           # small services can keep models together
  workflows/
    transfer_call.py
  adapters/
    contacts.py
    calls.py
tests/
  test_api.py
  workflows/
  adapters/
```

Not every service needs all of these. A single-purpose API may begin with `api.py`, `config.py`, one workflow module, one adapter module, and tests.

## Patterns To Reject

- Global connection-manager classes with mutable class state
- Settings instantiated at import time
- Dynamic route or command discovery that suppresses import failures
- Broad `except Exception` translated into client-visible details
- Blocking SDK calls inside async routes
- Remote I/O methods on database entities
- Feature flags used instead of explicit application composition
- Generic registries, proxies, cached-property frameworks, or concurrency layers created before repeated use
- Placeholder modules and commented implementations retained as architecture
- Tests that verify mocks instead of behavior

## Review Questions

Before accepting a service design, answer:

1. What workflows does this service own?
2. Can each workflow be read without framework or SDK trivia?
3. Where does every resource get created and closed?
4. Which module translates each external contract?
5. Which failures are expected, and who translates them?
6. Can API, CLI, and worker entry points reuse the same workflows?
7. Does every abstraction have at least one concrete reason to exist now?
8. Are tests exercising behavior through real boundaries where practical?

If these answers are obvious from the code, the service has the intended synthesis.
