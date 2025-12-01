# Repository Guidelines

- Keep README and documentation module-agnostic (avoid implying Riverpod-only support).
- When editing Markdown, keep the Usage section near the top and use concise bullet lists.
- Run `dart format` for any Dart code changes.

## Project Structure & Module Organization
- CLI entrypoint lives in `bin/dartd.dart`; core library exports in `lib/dartd.dart`.
- Analyzer logic sits under `lib/src/` (e.g., `analyzer.dart`, `usage_visitor.dart`, `commands.dart`); keep new utilities there and prefer small, focused files.
- Documentation belongs in `doc/`; package metadata in `pubspec.yaml`; lockfile is tracked via `pubspec.lock`.
- Tests should mirror the `lib/` layout under `test/`, one file per source file or feature.

## Build, Test, and Development Commands
- Install deps: `dart pub get`.
- Format: `dart format .` (required before commits).
- Static checks: `dart analyze .` to ensure analyzer passes.
- Run from source: `dart run bin/dartd.dart analyze --root lib` and `dart run bin/dartd.dart fix --root lib` (swap `--root` for alternate packages).
- Placeholder tests: `dart test` (add suites in `test/` before relying on this).

## Coding Style & Naming Conventions
- Use Dart defaults: 2-space indent, trailing commas where helpful, lowerCamel for members/functions, UpperCamel for types, SCREAMING_SNAKE for consts.
- Prefer small, pure functions; keep I/O inside `commands.dart` and helpers in `utils.dart`.
- Do not edit generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`); treat them as read-only inputs.
- Run `dart format .` and `dart analyze .` before pushing.

## Testing Guidelines
- Add unit tests beside the matching source (e.g., `lib/src/utils.dart` → `test/utils_test.dart`).
- Name tests for behavior, not implementation; keep fixtures lightweight.
- Validate CLI flows by exercising `dart run bin/dartd.dart analyze` against small sample trees under `test/fixtures/` when added.

## Commit & Pull Request Guidelines
- Commit messages: present-tense, imperative summaries (e.g., "Improve module grouping"); keep merges rare unless syncing.
- PRs should describe the problem and the approach, note any generated output touched, and include sample CLI output when changing reporting.
- Link related issues, list test commands run, and attach before/after snippets for analyzer/fix behavior when relevant.

## Security & Safety Notes
- The fixer intentionally skips generated files; preserve this guard when adding patterns.
- Review deletions carefully: files are removed only when no used module or non-module definitions remain. Consider dry-running `analyze` before `fix` on large repos.
