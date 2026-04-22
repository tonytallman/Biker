# 1. Modularizing the app with local Swift packages

- **Status**: Accepted
- **Date**: 2026-04-18
- **Supersedes**: (none)
- **Superseded by**: (none)

## Context

The Biker app needs clear boundaries between features and shared infrastructure so the codebase stays understandable as it grows. A monolithic target makes it easy to accumulate accidental coupling, harder to test units in isolation, and harder for multiple contributors to work without constant merge friction.

Xcode integrates Swift Package Manager (SPM) for local packages, which gives explicit module boundaries, declared dependencies between modules, and a standard layout that tooling and CI can reason about. The alternative is to keep everything in the app target and enforce boundaries only by convention, which does not scale as well.

If local packages depend on one another directly in `Package.swift`, the graph becomes brittle: cycles appear easily, refactors drag unrelated modules, and teams lose the ability to evolve or test packages in isolation. That coupling must be avoided by design.

## Decision

Modularize the application by splitting cohesive areas into **local Swift packages** living under the repository’s `local packages/` directory. Each package is a normal SPM package (`Package.swift` plus sources), referenced from the Xcode project like any other local package dependency.

**Local packages must remain independent of other local Swift packages.** They must not declare SPM dependencies on one another. A feature or core package that needs behavior from elsewhere expresses that need as **abstract protocols** (and related types) defined within its own module, not as imports of another local package’s concrete types.

**Wiring**: The **`DependencyContainer`** package (together with the app target where appropriate) is responsible for linking concrete implementations to the code that depends on those protocols—supplying adapters, factories, or registrations so dependent packages receive their dependencies without taking a direct package-to-package dependency on implementations.

The app target remains the overall composition root for app-level configuration while `DependencyContainer` centralizes how concrete types satisfy the protocol boundaries local packages declare.

## Consequences

**Positive**: Explicit dependency graphs without a tangled web of local-package imports; smaller compile units during development; clearer ownership of feature and core modules; easier unit testing against package boundaries (mock via protocols); alignment with SPM and future extraction or reuse of packages if ever needed.

**Negative**: More targets and `Package.swift` files to maintain; refactors that span modules require coordinated changes; contributors must understand SPM basics, the project’s package layout, and the protocol-plus-container pattern; some duplication of protocol surface area is possible if not coordinated.

**Risks / follow-ups**: Enforce the rule that local packages must not depend on other local packages (code review and tooling where practical). Watch for “protocol creep” (overly large abstraction surfaces) and for slipping concrete dependencies back in via shared helpers—keep package boundaries aligned with real domain or feature seams, not arbitrary file splits.
