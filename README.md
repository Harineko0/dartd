# dartd

Dead-code sweeper for Dart and Flutter projects. Scan for unused modules (files, classes, globals, generated assets, and more), report them, and optionally remove the cruft without touching generated files.

## Installation

```bash
dart pub global activate dartd
```

## Usage

- `dartd analyze` — scan `lib/` and report unused module groups and top-level declarations.
- `dartd analyze --root packages/my_feature/lib` — target a specific package or feature directory.
- `dartd fix` — remove unused modules and delete empty Dart files under `lib/`.
- `dartd fix --root packages/my_feature/lib` — apply fixes to a different root.

Typical workflow:

```bash
dartd analyze           # review what can go
dartd fix               # prune unused code safely
dartd analyze --root .  # optional sanity pass across the whole repo
```

## Highlights

- Module-aware grouping keeps related symbols together so one reference preserves the whole group.
- Analyzer and fixer understand files, classes, enums, extensions, typedefs, globals, and generated assets.
- Fast, CLI-first experience that works across Dart and Flutter codebases with no framework assumptions.
- Read-only stance toward generated files; they feed usage info but are never rewritten.

## What counts as usage

- Direct identifier references (e.g. `fooProvider`, `RemoteConfigParameter`).
- Type relationships (e.g. `extends LocationBasedUseCase`).
- Extension method calls (e.g. `children.withSpaceBetween()`).
- Typedef usage (e.g. `FutureCallback<T>`).
- Enum usage (e.g. `RemoteConfigParameter.values`).

## Safety rails

- Generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`) are never modified or deleted.
- Files are deleted only when they contain no used modules and no used top-level declarations.
- Designed for module-agnostic projects; framework-specific patterns are treated as regular Dart.

## Notes and limitations

- Heuristic detection: reflection, string lookups, or dynamic calls may appear unused.
- Always review `dartd analyze` output before committing fixes.

## Development

```bash
dart pub get
dart format .
dart analyze .
```

Run from source:

```bash
dart run bin/dartd.dart analyze --root lib
dart run bin/dartd.dart fix --root lib
```

## License

MIT
