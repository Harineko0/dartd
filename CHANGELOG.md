# Changelog

## 0.3.0
- Make analyzer Riverpod-aware:
    - Treat `@riverpod` / `@Riverpod`-annotated functions and their generated `*Provider` symbols as a single module group.
    - Consider a module group used if any symbol in the group is referenced from non-generated user code.
- Change deletion behavior:
    - Remove only user-code definitions (`@riverpod` functions and user-defined `*Provider`s) for unused module groups.
    - Never modify or delete generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`).
- Introduce safe file deletion:
    - Delete Dart files with no module definitions and no used top-level declarations.
    - Track usage of:
        - classes (including `abstract` classes and inheritance like `extends BaseClass`),
        - enums (`EnumName.values` etc.),
        - typedefs (`GenericTypeAlias`, e.g. `typedef FutureCallback<T> = ...`),
        - extensions and their members (e.g. `children.withSpaceBetween()`),
        - top-level functions and variables.
    - Consider usages across all files, including generated files, for non-module declarations.
- Protect `main.dart` from being deleted regardless of usage.
- Improve stability and correctness of unused detection in real-world Flutter / Riverpod projects.

## 0.1.0
- Initial release with `analyze` and `fix` commands.
- Heuristic unused class detection and module pruning.
- Ignores common generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`).
