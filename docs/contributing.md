# Contributing Guide

Thank you for your interest in contributing to smartslurmcommands!
This guide explains the project structure, coding style, and testing requirements to contribute.

## 1. Repository structure
```
smartslurmcommands/
│
├── cmd/                      # End-user commands (smartcancel, mqpwd, smartqueue, etc.)
│   └── <tool>/<tool>.sh      # Each command has its own directory and main script
│
├── lib/                      # Shared libraries used across commands
│   ├── core.sh               # Error handling, logging, require_cmd, current_user
│   ├── cfg.sh                # Optional configuration system
│   ├── util.sh               # Generic helper logic not tied to Slurm
│   ├── slurm.sh              # Slurm operators (squeue helpers, parsing, fields)
│   └── ui.sh                 # User-interaction helpers (pickers, menus)
│
├── scripts/                  # Installers, release scripts, CI helpers
├── docs/                     # Project documentation (In progress)
├── man/                      # Man pages for each CLI tool (ToDo)
├── tests/                    # All automated tests
│   ├── unit/                 # Unit tests (pure functions)
│   ├── integration/          # High-level integration tests for commands
│   └── helpers/              # Mock slurm commands, temp dirs, helpers
│
├── VERSION                   # Defines current version (bumped on release)
└── CONTRIBUTING.md           # You're here 🙂
```

## 2. Library Responsibilities

`lib/util.sh`
If the logic can be reused across commands and doesn't involve Slurm semantics, it belongs here.

`lib/slurm.sh`
If the logic interacts with `squeue`, `scancel`, `sbatch`, or Slurm fields → it belongs here.

## 3. Command Structure

Every command under `cmd/<tool>/<tool>.sh` must:

- have a shebang (#!/usr/bin/env bash)
- `set -Eeuo pipefail` and `IFS=$'\n\t'`
- load required libs in order:

```
source "$SSC_HOME/lib/core.sh"
source "$SSC_HOME/lib/util.sh"
source "$SSC_HOME/lib/slurm.sh"
```

avoid duplicating logic when util/slurm already provides helper functions.

## 4. Coding Standards

### Shell Style

I am following:

- POSIX-ish Bash, but Bash-only features allowed (mapfile, arrays, [[ ]])
- `set -Eeuo pipefail` always at top
- No eval
- No modification of global variables in util/slurm functions
- Functions prefixed with namespace:
```
util::foo
slurm::bar
core::baz
```
- While writing the documentation, I am following one sentence per line convention, which is easy for looking at diffs on github.

### 5. Testing

Test Framework: `bats-core`

All automated tests use bats. I have divide tests as:

- Unit tests (tests/unit/)
  These test pure functions:
  - util functions
  - slurm functions (using mocks)
  - time helpers
  Command execution must NOT appear here.

- Integration tests (tests/integration/)

  These run the actual commands end-to-end:
  - smartcancel with stdin
  - smartqueue filters
  - mqpwd behaviour
  - Default/fallback behaviour

- Mock Slurm

  I have simulated Slurm using:
  ```
  tests/helpers/slurm_mocks/squeue
  tests/helpers/slurm_mocks/scancel
  tests/helpers/slurm_mocks/scontrol
  ```
  `mock_slurm_path` prepends them to PATH.

This ensures tests run everywhere (GitHub Actions, macOS, developers’ machines) without Slurm.

### Running Tests Manually
```
chmod +x tests/helpers/slurm_mocks/*
bats -r tests/
```
