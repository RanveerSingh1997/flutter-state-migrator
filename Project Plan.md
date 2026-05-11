# Project Plan: Flutter State Migrator

## Goal
Make the migrator reliable enough for real Flutter codebases by prioritizing correctness, deterministic output, and strong regression coverage ahead of new feature expansion.

## Current Baseline

### Capabilities already in place
- AST-based scanning for Provider, BLoC/Cubit, GetX, and MobX patterns
- Assisted, safe, and aggressive migration modes
- Riverpod code-generation output with `@riverpod`, `part` files, and `build_runner` guidance
- Dependency graph warnings, rollback/snapshot support, audit reporting, dashboard, and VS Code integration
- Typed state-field IR, notifier selection, family detection, `ref.watch` / `ref.read` placement, and deeper body rewrites

### Current risks
- Some migrations still depend on text-pattern rewriting instead of syntax-aware restructuring
- Analyzer API drift and deprecation cleanup is not fully finished across all scanners
- End-to-end coverage is still thinner than the number of supported patterns implies
- Some docs and examples overstate maturity relative to the current regression net

## Planning Principles
1. **Correctness before breadth**: do not add new migration surfaces until current ones are stable.
2. **Typed transformations**: prefer typed IR and syntax-aware generation over string-only heuristics.
3. **Safe aggressive mode**: every aggressive rewrite needs focused fixtures and rollback coverage.
4. **One engine, many surfaces**: CLI, dashboard, wizard, reports, and VS Code should all reflect the same migration core.
5. **Proof over claims**: each roadmap phase ends with explicit exit criteria and regression tests.

## Delivery Roadmap

### Phase 31: Stabilization & Scanner Hardening
- Remove remaining scanner/API drift and analyzer compatibility issues
- Normalize typed IR across all adapters and generators
- Eliminate mixed old/new migration paths that produce inconsistent output
- Tighten provider naming, file header generation, and build-signature inference

**Exit criteria**
- `flutter analyze --no-fatal-infos` has no true errors in migrator code
- Scanner adapters all emit the same typed `LogicUnitNode` contract
- Focused unit tests cover the top migration regressions already found

### Phase 32: Transformation Correctness Sprint
- Replace fragile consumer/selector/provider call rewrites with safer structured edits where possible
- Finish chained-call handling such as `Provider.of(...).method()`
- Improve lifecycle-aware reads/watches for callbacks, init flows, and event handlers
- Expand body transformation coverage for collection updates, null-aware writes, and multi-step state mutations

**Exit criteria**
- Known migration bugs are reproducible in tests and stay green
- Aggressive-mode output remains syntactically valid on representative fixtures
- No mixed `@riverpod` + manual provider emission remains in migrated logic units

### Phase 33: Project-Level Integration
- Harden dependency updates for `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, and `build_runner`
- Make generated-file handling predictable in monorepos and multi-package workspaces
- Improve import cleanup, part-file management, and build-runner guidance
- Ensure snapshots and rollback cover generated artifacts and pubspec changes

**Exit criteria**
- Migration works across single-package and multi-package fixtures
- Generated files and dependency edits are reflected cleanly in reports and rollback manifests
- Dry-run, safe, assisted, and aggressive flows stay aligned

### Phase 34: Verification Matrix & Fixtures
- Build a fixture matrix for Provider, BLoC, GetX, and MobX
- Add golden-style output checks for critical rewrite families
- Add integration coverage for CLI modes, report output, and snapshot/rollback
- Keep a dedicated regression suite for every previously discovered migration bug

**Exit criteria**
- Each supported library has at least one realistic fixture project
- Critical rewrites are covered by focused tests plus at least one end-to-end flow
- CI runs the regression suite on every push and pull request

### Phase 35: Product Readiness & Documentation Alignment
- Rewrite documentation to reflect verified capabilities instead of aspirational scope
- Align wizard prompts, dashboard summaries, and VS Code actions with the current engine
- Improve troubleshooting guidance for generated-code workflows and migration limits
- Prepare a clean release once stabilization and verification phases are complete

**Exit criteria**
- README, migration guide, examples, and CLI help all describe the same supported behavior
- Release notes are driven by tested capabilities
- The project can be presented as reliable, not just feature-rich

## Immediate Implementation Order
1. Finish scanner hardening and typed IR consistency
2. Close correctness gaps in transformation rewrites
3. Strengthen integration behavior around dependencies, imports, and generated files
4. Expand fixture-based regression coverage
5. Refresh docs and release narrative after behavior is verified

## Initial Execution Backlog
- **Scanner modernization**: finalize analyzer API cleanup and adapter consistency
- **Transformation safety**: harden chained calls, selector/consumer rewrites, and lifecycle contexts
- **Typed generation**: improve state inference, family signatures, and code-gen defaults
- **Integration flow**: tighten dependency management, rollback coverage, and monorepo handling
- **Verification**: grow focused tests into a stable multi-library fixture matrix
- **Documentation**: reduce hype, document real guarantees, and explain current migration boundaries

## Success Definition
The migrator is successful when a team can run it on a real codebase, review deterministic output, recover safely when needed, and trust that documented behavior is backed by tests rather than roadmap claims.
