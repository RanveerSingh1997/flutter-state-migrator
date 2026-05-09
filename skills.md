# Skills Plan: Flutter State Migrator

This document outlines the key technical skills, concepts, and design patterns demonstrated and applied in the development of the Flutter State Migrator CLI tool.

## Core Technical Skills

### 1. Abstract Syntax Tree (AST) Parsing
- Using the `analyzer` package to parse Dart source code into an AST.
- Implementing custom `RecursiveAstVisitor` (e.g., `ProviderAdapter`) to traverse and extract specific code structures (`ChangeNotifierProvider`, `Consumer`, `Provider.of`, etc.).
- Safely handling source code diagnostics and parsing errors during code traversal.

### 2. Intermediate Representation (IR)
- Designing decoupled IR models (`ProviderNode`, `LogicUnitNode`, `WidgetNode`, etc.) to abstract the extracted AST data.
- Establishing a clear boundary between the "scanning" phase and the "generation/transformation" phase.

### 3. Automated Code Transformation
- Calculating text offsets and lengths to perform precise string replacements.
- Safely unwrapping Flutter widget trees (e.g., extracting the `child` argument from a `ChangeNotifierProvider`) programmatically.
- Generating modern, functional code structures (Riverpod global providers, `ConsumerWidget`, `ref.read`/`ref.watch`) to replace legacy patterns.

### 4. Dart CLI Application Development
- Building a modular Command Line Interface (CLI) using the `args` package.
- Implementing multiple runtime execution strategies (Safe, Assisted, and Aggressive modes).
- Graceful error handling and terminal output formatting.

## Architecture & Design Patterns

### 1. Adapter Pattern
- Used in `ProviderAdapter` to adapt the raw Dart AST nodes into the project's custom domain models (Intermediate Representation).

### 2. Strategy Pattern (Conceptual)
- Providing different migration strategies (Safe mode injecting comments, Assisted mode generating blueprints, Aggressive mode rewriting source files).

### 3. Modular Architecture
- Separating concerns into distinct modules:
  - **Scanner**: Reads files and extracts nodes.
  - **Models**: Defines the data structures.
  - **Generator**: Generates snippets and suggestions.
  - **Transformer**: Applies the actual code edits.

## Flutter State Management Knowledge
- **Provider**: Deep understanding of `ChangeNotifier`, `ChangeNotifierProvider`, `Consumer`, `Selector`, and `context.read`/`watch`.
- **Riverpod**: Mastery of `StateNotifierProvider`, `ConsumerWidget`, `WidgetRef`, and global provider declarations.

---
*Note: Update this document as new features, patterns, or tools are integrated into the project.*
