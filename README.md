# Flutter State Migrator 🚀

An automated CLI tool to migrate your Flutter applications from `provider` to `riverpod` with minimal manual effort.

## Features

- **AST-based Analysis**: Uses the official Dart analyzer to accurately identify Provider patterns.
- **Three Migration Modes**:
  - `assisted`: Generates side-by-side Riverpod blueprints for manual review.
  - `safe`: Injects `TODO` comments into your existing code to guide manual migration.
  - `aggressive`: Automatically rewrites your source code, converts widgets to `ConsumerWidget`, and generates global providers.
- **Advanced Pattern Support**: Handles `MultiProvider`, `Selector`, `Consumer`, and `Provider.of` automatically.
- **Auto-formatting**: Automatically runs `dart format` on modified files.

## Installation

```bash
# Clone the repository
git clone https://github.com/RanveerSingh1997/flutter-state-migrator.git
cd flutter_state_migrator

# Get dependencies
flutter pub get
```

## Usage

Run the migrator on your target project:

```bash
dart run bin/migrator.dart --mode <mode> <path_to_project>
```

### Examples

**Aggressive Migration (Automatic Rewrite):**
```bash
dart run bin/migrator.dart --mode aggressive my_flutter_project
```

**Assisted Migration (Generate Blueprints):**
```bash
dart run bin/migrator.dart --mode assisted my_flutter_project
```

## How it Works

1. **Scan**: The tool scans your project for `ChangeNotifier` classes and Provider widgets.
2. **Transform**: It computes precise text replacements to modernize your code.
3. **Generate**: It appends the necessary Riverpod global provider definitions to your files.
4. **Format**: It cleans up the generated code using standard Dart formatting.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for our branching strategy and development workflow.

## License

This project is licensed under the MIT License.
