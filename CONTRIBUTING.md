# Contributing

Changes should preserve deterministic output and the no-runtime-dependency design. Add regression coverage for date arithmetic, calendar layout, serialization, and consumer-facing rule behavior. Run `bazel test //tests/... //examples/year_turn/... //examples/bcr/...` and `buildifier -r .` before submitting changes.

Public API changes require documentation updates and a changelog entry. Published BCR versions are immutable; corrections belong in a new upstream release.
