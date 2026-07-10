# Noridoc: docs

Path: @/docs

### Overview

Contains design specifications and implementation plans for the Claude Code Superpowers integration feature.

### How it fits into the larger codebase

The docs directory holds pre-development design artifacts rather than post-implementation documentation. It is not consulted at runtime and is excluded from the install package. The `superpowers/` subdirectory contains specs and plans that predate the v0.1.0 implementation and describe the target architecture for the Superpowers plugin management feature.

### Core Implementation

Two subdirectories:
- `superpowers/specs/` -- Design specifications defining the functional requirements
- `superpowers/plans/` -- Implementation plans with step-by-step instructions

These are reference documents for understanding design intent but may not reflect the current implementation exactly.

### Things to Know

- The contents of `docs/` are not installed by `install.sh`; they only exist in the development checkout
- Documents here are not noridocs -- they are pre-development design artifacts
