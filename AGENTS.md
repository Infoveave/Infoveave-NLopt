# Repository Agent Instructions

## Scope

This repository owns the generic `Infoveave.NLopt` managed package and verified NLopt native runtime bundles. Keep Infoveave What-If formulas, rows, weights, scenarios, and business result semantics out of this repository.

## Native-source safety

- Build only the immutable NLopt source recorded in `eng/native-source.json`.
- Never add an implicit download to restore, build, test, pack, publish, or package MSBuild targets.
- Never fall back to a system-installed NLopt library.
- Do not copy source from NLoptNet. It is reference-only at the recorded commit.
- Managed NuGet packages must not contain native libraries.

## Version control

- Use GitButler (`but`) for status, diffs, branches, commits, pushes, and pull requests.
- Use a dedicated branch per WIF task.
- Do not push or open a pull request unless explicitly requested.

