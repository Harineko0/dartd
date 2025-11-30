# dartd

CLI to analyze and remove unused **Riverpod providers and modules** in a Dart / Flutter project.

This tool is designed around the Riverpod codegen style:

- `@riverpod` / `@Riverpod`-annotated functions in user code
- Generated `*Provider` symbols in `.g.dart` files

and performs safe, heuristic-based cleanup of unused modules and unused Dart files.

## Features

- `analyze`
  - Reports unused Riverpod module groups (e.g. `@riverpod Foo` + `FooProvider`).
  - Lists Dart files under `--root` that can be safely deleted because they contain no used modules or top-level declarations.
- `fix`
  - Removes unused Riverpod **definitions in user code only** (non-generated files).
  - Deletes Dart files that contain:
    - no module definitions, and  
    - no used top-level declarations (classes, enums, typedefs, extensions, etc.).
- Riverpod-aware grouping:
  - Treats `@riverpod Foo()` and `FooProvider` (and related generated providers) as a single **module group**.
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
````

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

## Notes and limitations

* **Heuristic detection:**
  Code referenced only via reflection, string-based lookups, or `dynamic` calls may be treated as unused.
* **Generated files are never modified:**
  Files like `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart` are not rewritten or deleted.
* **Riverpod-specific:**
  Module detection is centered around Riverpod’s `@riverpod` / `@Riverpod` annotations and `*Provider` naming.
  Other DI / state management patterns are not specially handled.
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
