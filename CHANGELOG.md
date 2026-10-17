# Changelog

## 0.2.0 — 2026-10-18

- Added read-only CPU temperature through AppleSMC, without sudo or a background service.
- Report the mean of available mapped CPU sensors in JSON and text, with source, contributing sensor keys/values, and explicit unavailable reasons.
- Added generation-specific M1–M5 and Intel CPU sensor candidates, float/fixed-point decoding, and invalid-reading checks. GPU temperature remains unsupported.
- Verified CPU readings on Apple M4 / macOS 26.3.1; other hardware and older macOS runtime coverage are unverified.

## 0.1.1 — 2026-09-08

- Unified Skill installation in `~/.agents/skills`, with a Claude Code compatibility symlink.
- Updated standalone and combined distribution documentation for the Capsomnia 4.0.0+ release line.
- Added installer coverage for shared Skill migration and conflict handling.

## 0.1.0 — 2026-09-08

Initial public release.

- Read-only `macready` CLI with human-readable and JSON snapshots.
- Power source, battery presence, capacity, charging, battery temperature, thermal state, lid, external display, and global sleep setting observations.
- JSON schema version 1, UTC capture time, and explicit unavailable fields.
- Shared `macready` Skill for Codex and Claude Code.
- Standalone installer with shared Codex/Claude Code Skill installation; compatible with bundled Capsomnia Tools distribution.
- Independent `MacStateCore` Swift package library for shared observations.
- macOS 13.5 minimum target and universal Apple silicon / Intel package build.

CPU and GPU temperatures are unsupported and remain `null`. Battery temperature uses the Smart Battery 0.1 K representation.
