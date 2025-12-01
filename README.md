<div align="center">
    <img src="https://github.com/user-attachments/assets/4ac64317-b7b6-4b65-b351-c94d5f8bd057" alt="dartd logo" width="256" height="256">
    <h1>dartd</h1>
</div>

# dartd

[![Pub](https://img.shields.io/pub/v/dartd?label=pub&logo=dart&logoColor=white)](https://pub.dev/packages/dartd)
[![CI](https://github.com/Harineko0/dartd/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Harineko0/dartd/actions/workflows/ci.yml)
![Dart SDK](https://img.shields.io/badge/dart-%E2%89%A53.0-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Dead-code sweeper for Dart and Flutter projects. Scan for unused modules (files, classes, globals, generated assets, and more), report them, and prune safely—no edits to generated files.

## Usage

- `dartd analyze --root <path> [--json]` — scan for unused modules and declarations (defaults to the current directory).
- `dartd fix --root <path> [--dry-run]` — remove unused modules, class members (methods/getters/setters/fields), and delete empty Dart files under `lib/` (dry-run to preview).
- `dartd fix --remove method` — narrow removals (`file`, `class`, `function`, `var`, `method`, `member`; default: `all`).
- `dartd analyze --root packages/feature/lib` — target a specific package or feature folder.
- `dartd fix --root packages/feature/lib` — apply fixes to a different root.

Quick flow:

```bash
dartd analyze                  # review what can go
dartd fix                      # prune unused code safely
dartd analyze --root . --json  # optional JSON pass for tooling/CI
dart run build_runner build -d # regenerate assets; generated files stay untouched
```

## Why dartd

- Module-aware grouping keeps related symbols together so one reference preserves the whole unit.
- Understands files, classes (and unused members), enums, extensions, typedefs, globals, and generated assets.
- Framework-agnostic analysis that works across Dart and Flutter codebases.
- Fast, CLI-first ergonomics with JSON output for automation.

## What counts as usage

- Direct identifier references (e.g. `fooProvider`, `RemoteConfigParameter`).
- Type relationships (e.g. `extends LocationBasedUseCase`).
- Extension method calls (e.g. `children.withSpaceBetween()`).
- Typedef usage (e.g. `FutureCallback<T>`).
- Enum usage (e.g. `RemoteConfigParameter.values`).

## Safety rails

- Generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`) are never modified or deleted.
- Files are deleted only when they contain no used modules and no used top-level declarations.
- Constructor params/initializers tied solely to removed fields are pruned alongside those fields.

## Limitations

- Heuristic detection: reflection, string lookups, and dynamic calls may appear unused.
- Mixed constructors are edited conservatively; review `dartd analyze` output before committing fixes.

## Install

```bash
dart pub global activate dartd
```

## Development

```bash
dart pub get
dart format .
dart analyze .
dart run bin/dartd.dart analyze --root lib
dart run bin/dartd.dart fix --root lib
```

## License

MIT
