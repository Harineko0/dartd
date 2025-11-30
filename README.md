# dartd

CLI to scan a Dart / Flutter project for unused modules (files, classes, global functions, global variables, generated assets, etc.), report them, and optionally remove the dead code.

The analyzer groups related declarations (for example, an annotated factory and its generated output) so that any reference to the group keeps the entire module intact.

## Usage

```bash
# Analyze under lib/ by default
dartd analyze

# Analyze a specific root directory
dartd analyze --root lib

# Apply fixes under lib/ (remove unused modules and deletable files)
dartd fix

# Apply fixes to another directory
dartd fix --root packages/my_feature/lib
```

Options:

* `-r, --root`
  Root directory to analyze (default: `lib`).

## Features

- `analyze`
  - Reports unused module groups (e.g. a service class and its generated adapter) and unused top-level declarations.
  - Lists Dart files under `--root` that can be safely deleted because they contain no used modules or top-level declarations.
- `fix`
  - Removes unused module definitions in user code only (non-generated files).
  - Deletes Dart files that contain:
    - no module definitions, and
    - no used top-level declarations (classes, enums, typedefs, extensions, etc.).
- Module-aware grouping:
  - Treats related symbols (e.g. annotated factories plus generated code, or user entrypoints plus their generated providers) as a single **module group**.
  - If **any** symbol in the group is referenced from user code, the whole group is kept.
- Generated file safety:
  - Never modifies generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`).
  - Generated files are used only as **a source of usage information**, not as edit targets.
- Usage tracking:
  - Understands usage through:
    - direct identifier references (e.g. `fooProvider`, `RemoteConfigParameter`),
    - type names (e.g. `extends LocationBasedUseCase`),
    - extension method calls (e.g. `children.withSpaceBetween()`),
    - typedef usage (e.g. `FutureCallback<T>`),
    - enum usage (e.g. `RemoteConfigParameter.values`).

## Install

```bash
dart pub global activate dartd
```

## Notes and limitations

* **Heuristic detection:**
  Code referenced only via reflection, string-based lookups, or `dynamic` calls may be treated as unused.
* **Generated files are never modified:**
  Files like `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart` are not rewritten or deleted.
* **Module shapes supported:**
  Designed to work with user-defined modules (including generated counterparts) plus standard top-level declarations. Framework-specific patterns (DI, state management, code generators) are scanned as regular Dart code without bespoke handling.
* **Review changes:**
  Always review the `analyze` output and, if needed, use version control to inspect what `fix` removed.

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
