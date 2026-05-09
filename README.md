# 🚀 Flutter State Migrator

[![CI/CD](https://github.com/RanveerSingh1997/flutter-state-migrator/actions/workflows/dart_test.yml/badge.svg)](https://github.com/RanveerSingh1997/flutter-state-migrator/actions/workflows/dart_test.yml)
[![Pub Version](https://img.shields.io/pub/v/flutter_state_migrator)](https://pub.dev/packages/flutter_state_migrator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Flutter State Migrator** is a powerful CLI tool designed to automate the modernization of Flutter applications by migrating state management from **Provider** (or **BLoC/Cubit**) to **Riverpod**.

Using advanced AST (Abstract Syntax Tree) analysis, it intelligently refactors your source code, updates imports, and injects Riverpod best practices, saving you days of manual refactoring.

---

## ✨ Key Features

- **AST-Based Transformation**: Intelligent source code rewriting using the official Dart analyzer.
- **Multi-Library Support**: Migrates from `Provider`, `ChangeNotifierProvider`, `Bloc`, and `Cubit`.
- **Intelligent Logic Mapping**: Refactors `notifyListeners()` and `emit()` into idiomatic Riverpod state updates.
- **Interactive Dry-run**: Preview all changes with colorized console diffs before applying them.
- **Monorepo Aware**: Automatically detects and handles multiple packages in a single workspace.
- **VS Code Integration**: Right-click to migrate directly from your IDE.
- **Detailed Audit Reports**: Generates `migration_report.json` with complexity scores and metrics.
- **Import Management**: Automatically manages `flutter_riverpod` imports and prunes legacy ones.

---

## 🚀 Quick Start

### Installation

Install the migrator globally via pub.dev:

```bash
dart pub global activate flutter_state_migrator
```

### Usage

Run the migrator on your project directory:

```bash
# Preview changes (Dry Run)
flutter_state_migrator --mode aggressive --dry-run .

# Apply changes directly
flutter_state_migrator --mode aggressive .

# Generate a dependency visualization graph
flutter_state_migrator --visualize .
```

---

## 🛠️ Configuration

You can customize the migration behavior by adding a `migrator_config.yaml` to your project root:

```yaml
provider_naming: camelCase  # or PascalCase
auto_merge_state: true      # Toggle automatic state class merging
```

---

## 📖 Documentation

- [Detailed Migration Guide](MIGRATION_GUIDE.md): Understand how patterns are transformed.
- [VS Code Extension](vscode-extension/README.md): IDE integration details.
- [Contributing](CONTRIBUTING.md): How to help improve the migrator.

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) to get started.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ for the Flutter Community.
