# Changelog

## 0.1.0 — 2026-09-08

Initial public release.

- Read-only `macready` CLI with human-readable and JSON snapshots.
- Power source, battery presence, capacity, charging, battery temperature, thermal state, lid, external display, and global sleep setting observations.
- JSON schema version 1, UTC capture time, and explicit unavailable fields.
- Shared `macready` Skill for Codex and Claude Code.
- Standalone installer with optional Skill destinations; compatible with bundled Capsomnia Tools distribution.
- Independent `MacStateCore` Swift package library for shared observations.
- macOS 13.5 minimum target and universal Apple silicon / Intel package build.

CPU and GPU temperatures are unsupported and remain `null`. Battery temperature uses the Smart Battery 0.1 K representation.
