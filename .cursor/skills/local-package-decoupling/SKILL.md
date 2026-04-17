---
name: local-package-decoupling
description: >-
  Decouples local Swift packages by defining abstractions in the consumer and
  wiring concrete types in DependencyContainer or the Biker app. Use when adding
  cross-package behavior without a new Package.swift path dependency, removing a
  forbidden local dependency, refactoring toward package independence, or when
  the user mentions protocols, adapters, or composition root.
---

# Local package decoupling

Follow this workflow when two local packages need to interact but [package-independence.mdc](.cursor/rules/package-independence.mdc) forbids (or you want to avoid) a direct SPM dependency between them.

Policy details and allowed exceptions live only in that rule; do not bypass them here.

## Workflow

1. **Identify the consumer** — the module that needs a capability (types, publishers, services) owned by another local package.

2. **Define a minimal abstraction in the consumer** — usually a `protocol` (or a small struct enum / closure type) that describes only what the consumer needs. Name and shape it to match how the consumer uses the dependency, not the provider’s internal API.

3. **Keep provider types in the provider package** — concrete types, frameworks, and vendor-specific code stay in the package that already owns them.

4. **Wire at the composition root** — implement the protocol with a concrete type or adapter in **DependencyContainer** (preferred for this repo) or the **Biker** app target. Register instances, factories, or environment values there so the consumer receives the abstraction only.

5. **Avoid leaking imports** — the consumer target must not `import` the provider module if there is no package dependency. The adapter in DependencyContainer may import both sides.

## Testing

- Consumer unit tests: depend on the protocol; use a test double or mock implementation in the test target.
- Integration of real behavior: exercise the adapter in DependencyContainer tests or app-level tests if you have them.

## Swift-oriented notes

- Prefer narrow protocols over “pass the whole” concrete service type.
- If the consumer needs only one function or publisher, a struct holding a closure or `AnyPublisher` might be enough instead of a formal protocol.
- When Swift access control blocks visibility across modules without a dependency, the abstraction in the consumer is the supported boundary; do not widen `public` on provider types just to satisfy the consumer.
