# Flutter State Migrator VS Code Extension

This extension surfaces Flutter Architecture Intelligence diagnostics directly in VS Code.

## Features

- Inline diagnostics backed by `migrator --ide-json`
- Quick fixes for:
  - migrating the current Dart file
  - migrating the current project
  - showing architecture recommendations
  - opening the migration guide
- Explorer context menu actions for file and folder migration

## Local Development

```bash
cd vscode-extension
npm install
npm run compile
```

Then open `vscode-extension/` in VS Code and press `F5` to launch an Extension Development Host.

## Local Installation

Package a local `.vsix`:

```bash
cd vscode-extension
npx @vscode/vsce package
```

Install it with:

```bash
code --install-extension flutter-state-migrator-1.0.0.vsix
```

## Requirements

- VS Code 1.80+
- The `migrator` CLI available in your environment
- A Flutter/Dart workspace for diagnostics and migration actions
