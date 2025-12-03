# dartd CLI usage

## Commands
### analyze
Reports unused classes and `lib/` modules.
```
dartd analyze --root <path> [--json]
```
- `--root`, `-r`: project root (default: current directory)
- `--json`: emit JSON report

### fix
Removes unused class blocks, unused methods/getters/setters/fields (and constructor params/initializers tied only to them), and unreferenced `lib/` modules.
```
dartd fix --root <path> [--dry-run]
```
- `--root`, `-r`: project root (default: current directory)
- `--dry-run`: show planned removals without writing files
- `--remove`: specify what to remove (`file`, `class`, `function`, `var`, `method`, `member`, `import`, or `all`)

## Output details
- Unused classes: listed with class name and file path.
- Unused modules: `lib/` files not imported/exported/parted within the package (excluding generated files and main package library).

## Behavior & limitations
- Heuristic: counts references by name; reflection/dynamic usage may be missed.
- Skips common generated files: `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.gr.dart`.
- Only considers package-local imports/exports/parts for module reachability.

## Examples
Analyze with JSON:
```
dartd analyze --json
```

Dry-run fix:
```
dartd fix --dry-run
```

Target a specific project:
```
dartd analyze --root /path/to/project
```
