# Changelog

## 0.4.0
- Add class methods/members removal feature
- Handled unused fields even when referenced by constructors: collectors now attach extra removal ranges for constructor field formals/initializers and drop entire constructors when they only served unused   fields; removals apply alongside module fixes with new OffsetRange support.
- Loop fix deletions until stable and defer change logs
- Adjusted fix application to collapse whitespace around deletions so extra blank lines like }\n\n\n@riverpod are reduced to a single blank line while keeping next-line indentation intact (lib/src/analyzer.dart).
- Added a --remove multi-option to fix so users can target specific unused declaration kinds (file/class/function/var/method/member, default all) and refreshed CLI help/usage text in bin/dartd.dart.

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
