# Compatibility

| Component | 0.1 contract |
| --- | --- |
| macOS | Deployment target 13.5 or later. Hardware/session-dependent readings can be unavailable. |
| Architectures | Package builds Apple silicon `arm64` and Intel `x86_64`. Building both is not equivalent to testing both on hardware. |
| CLI | `macready [status] [--json]`, help, and version. No Capsomnia dependency. |
| JSON | `schema_version: 1`. Consumers should reject unsupported schema versions, tolerate extra fields, and retain null/unknown values. |
| Skill | One `macready` Skill installed in `~/.agents/skills/macready`, with a Claude Code compatibility link. The agent must be able to execute a local command. |
| Capsomnia Tools | Can package this CLI and Skill alongside `cpsm` and the `capsomnia` Skill. No app is needed for MacReady itself. |
| `MacStateCore` | Swift library source in this repository is authoritative. Capsomnia vendors a copy for its own offline build. |

Version 0.1 does not promise a stable Swift library API. When changing `MacStateCore`, update the vendored Capsomnia copy and its source/version record together, then run both projects' tests. JSON changes that invalidate existing field meanings or types require a schema version change.

Battery temperature relies on an IORegistry property that may vary across hardware or macOS releases. CPU/GPU temperatures are not implemented. Thermal `nominal` and `sleep_disabled: true` are observations, not promises of safe operation or continued work.
