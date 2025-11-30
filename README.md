# dartd

CLI to analyze and remove unused Dart classes or modules in a project.

## Features
- `analyze`: reports unused classes and `lib/` modules (files not imported/exported/parted).
- `fix`: removes unused class blocks and unreferenced `lib/` modules.
- Supports JSON output for tooling and `--dry-run` for safe previews.

## Install
```bash
dart pub global activate dartd
```

## Usage
```bash
dartd analyze --root /path/to/project [--json]
dartd fix --root /path/to/project [--dry-run]
```

Options:
- `-r, --root`: project root (default: current directory)
- `--json`: emit analysis as JSON
- `--dry-run`: show planned removals without writing files

## Notes and limitations
- Heuristic detection: classes referenced via reflection/dynamic calls may be flagged as unused.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`) are ignored.
- Module detection only considers imports/exports/parts within the package.
- Review output before applying fixes on critical codebases.

## Development
```bash
dart pub get
dart format .
dart analyze .
```

## License
MIT
