# 🚀 Flutter Architecture Intelligence Platform

[![CI/CD](https://github.com/RanveerSingh1997/flutter-state-migrator/actions/workflows/dart_test.yml/badge.svg)](https://github.com/RanveerSingh1997/flutter-state-migrator/actions/workflows/dart_test.yml)
[![Pub Version](https://img.shields.io/pub/v/flutter_state_migrator)](https://pub.dev/packages/flutter_state_migrator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The **Flutter Architecture Intelligence Platform** is a production-grade suite designed to help teams modernize, analyze, and govern large-scale Flutter codebases. 

Evolved from the Flutter State Migrator, this platform goes beyond simple code rewriting to provide deep semantic understanding, architecture health metrics, and automated governance.

---

## ✨ Key Capabilities

- **Semantic Architecture Analysis**: Uses AST-based scanning to build a comprehensive dependency graph of your application.
- **Multi-Framework Migration**: Automates the transition from `Provider`, `BLoC/Cubit`, `GetX`, and `MobX` to modern `Riverpod` with `@riverpod` annotations.
- **Architecture Health Scoring**: Real-time scoring (0-100) based on detected architecture smells like God Components, State Explosion, and High Coupling.
- **Automated Governance**: Enforce scalable development practices by defining forbidden layer dependencies and complexity limits.
- **Verification Matrix**: Golden-style regression fixtures validate scanner, transformer, visualization, and integration behavior across supported frameworks.
- **Safety-First Transformation**: Integrated snapshot and manifest-based rollback systems ensure every aggressive rewrite is reversible.
- **Interactive Dashboard**: Review architecture health, governance posture, migration rollout, and Mermaid relationship diagrams from one place.
- **IDE Intelligence**: Structured diagnostics and quick-fix recommendations surface architecture warnings inline in the optional VS Code companion extension.
- **AI Guidance with Safe Fallbacks**: `--ai` prefers a local Ollama endpoint for migration recommendations and falls back to deterministic architecture guidance when the model is unavailable.
- **Monorepo & Workspace Intelligence**: Automatically detects and validates architecture across multi-package Flutter ecosystems.

---

## 🚀 Quick Start

### Installation

Install the platform CLI globally via pub.dev:

```bash
dart pub global activate flutter_state_migrator
```

*Note: The package is published as `flutter_state_migrator`, providing the `migrator` CLI command.*

### Usage

Run the intelligence engine on your project directory:

```bash
# Analyze architecture and detect smells
migrator .

# Preview migration changes (Dry Run)
migrator --mode aggressive --dry-run .

# Apply migration and governance fixes
migrator --mode aggressive .

# Generate a visual architecture relationship graph
migrator --visualize .

# Emit IDE diagnostics as JSON for editor integrations
migrator --ide-json .

# Print AI-assisted guidance using a local Ollama model when available
migrator --ai .
```

---

## ⚖️ Architecture Governance

Define your architecture contracts in `migrator_config.yaml`:

```yaml
# Governance Rules
governance:
  forbidden_imports:
    - presentation -> data
    - ui -> repository
  feature:
    max_dependencies: 8

# Naming Conventions
provider_naming: camelCase
```

---

## 📖 Documentation

- [Project Plan](Project_Plan.md): Roadmap and technical vision.
- [Detailed Migration Guide](MIGRATION_GUIDE.md): Understand how patterns are transformed.
- [VS Code Extension](vscode-extension/README.md): Optional companion integration for editor diagnostics and quick fixes.

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) to get started.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ for the Flutter Community.
