# MacReady

Give your AI agent a fresh view of your Mac's power, battery, heat, lid, and sleep settings.

MacReady is a small, read-only macOS CLI and agent Skill by [Taketo Fujimaki](https://github.com/fuji-mak). Run one command, get a timestamped snapshot, and let your agent use that information when discussing a long-running task.

[日本語](README.ja.md) · [Changelog](CHANGELOG.md) · [Release preparation](docs/releasing.md) · [MIT license](LICENSE)

> **v0.1.1 — current public release, September 8, 2026.** MacReady is
> independently usable and does not require Capsomnia.

[Download MacReady.pkg](https://github.com/fuji-mak/MacReady/releases/latest/download/MacReady.pkg)

```sh
macready status --json
```

## What it reads

- Power source, battery presence, battery percentage, and charging state.
- Battery temperature and macOS thermal state.
- Lid state, external display connection, and the global `SleepDisabled` setting.
- Capture time and explicit reasons for unavailable observations.

MacReady exits after each snapshot. It does not require Capsomnia, elevated privileges, a background service, or a network connection. It does not change power settings or decide automatically whether a task should continue.

## Install

Requires **macOS 13.5 or later**. MacReady 0.1.1 ships as a universal
Apple silicon / Intel package.

Open the [MacReady.pkg](https://github.com/fuji-mak/MacReady/releases/latest/download/MacReady.pkg).
The installer contains:

| Component | Destination |
| --- | --- |
| Required `macready` CLI | `/usr/local/bin/macready` |
| Shared Skill | `~/.agents/skills/macready/SKILL.md` |
| Claude Code link | `~/.claude/skills/macready` |

Codex and Claude Code use the same shared Skill; the installer has no agent destination choices. Installer authentication is required to write `/usr/local/bin`; running MacReady needs no `sudo`. The Skill targets the user logged in to the Mac's console session.

MacReady can also be included with `cpsm` and both Skills in
[Capsomnia Tools](https://github.com/fuji-mak/cpsm/releases/latest/download/Capsomnia-Tools.pkg),
downloaded from Capsomnia's advanced settings. The Capsomnia app package remains separate.

## Use

```sh
macready                    # Human-readable snapshot
macready status --json      # Structured snapshot for agents and scripts
macready --help
macready --version
```

With the Skill installed, ask your agent questions such as “What is my Mac's current power and thermal state?” The agent needs permission to run local commands; installing a Skill does not itself connect a remote device to your Mac.

Example JSON, abbreviated and illustrative:

```json
{
  "schema_version": 1,
  "captured_at": "2026-09-07T05:00:00Z",
  "power": {
    "source": "ac",
    "battery_present": true,
    "battery_percent": 80,
    "charging": false
  },
  "thermal_state": "nominal",
  "temperature": {
    "battery_celsius": 27.15,
    "battery_raw": 3003,
    "battery_source": "AppleSmartBattery.Temperature (Smart Battery 0.1 K)",
    "cpu_celsius": null,
    "gpu_celsius": null
  },
  "lid_closed": false,
  "external_display_connected": false,
  "sleep_disabled": false,
  "unavailable": {
    "temperature.cpu_celsius": "CPU temperature is not supported by MacReady 0.1.",
    "temperature.gpu_celsius": "GPU temperature is not supported by MacReady 0.1."
  }
}
```

### Interpret the snapshot

| Field | Meaning and limits |
| --- | --- |
| `power.source` | `ac`, `battery`, `ups`, or `unknown`. AC power does not mean the battery is charging. |
| `thermal_state` | `nominal`, `fair`, `serious`, `critical`, or `unknown`. macOS can report `nominal` for an unsupported or unknown state, so it is not a safety guarantee. |
| `temperature.battery_celsius` | Battery temperature, not CPU/GPU temperature. IORegistry `Temperature` is converted from Smart Battery 0.1 K using `raw / 10 - 273.15`. This property is not a stable public API. |
| `temperature.cpu_celsius` / `gpu_celsius` | Unsupported in 0.1; always `null`. |
| `lid_closed` / `external_display_connected` | Observed state, or `null` when unavailable. A Mac without a lid may have no lid reading. |
| `sleep_disabled` | System-wide `SleepDisabled` from `pmset -g`. It does not describe all sleep assertions or guarantee that work survives lid closure. |
| `unavailable` | Reasons for missing readings. A batteryless Mac's capacity and charging values are non-applicable and remain `null`. |

JSON uses `schema_version: 1`. Missing data stays `null` or `unknown`; a successful command can return a partial snapshot. Read consumers should check the schema version and tolerate additional fields. Re-read for current conditions; this CLI provides no continuous monitor or runtime estimate.

Exit codes: **0** for a snapshot, help, or version; **2** for invalid arguments; **1** for snapshot encoding failure. With `--json`, argument errors are JSON objects with `ok: false` and `error`.

## Build from source

Requires the macOS SDK and Swift 5.9 or later (Xcode or compatible Command Line Tools).

```sh
swift build -c release --product macready
.build/release/macready status --json
swift test

# Build a local package with an ad hoc signed binary; do not publish this package.
SKIP_SIGNING=true ./scripts/build-pkg.sh
```

The package script builds both architectures by default and writes `dist/MacReady-0.1.1.pkg`, `dist/MacReady.pkg`, and `dist/SHA256SUMS.txt`. See [release preparation](docs/releasing.md) for signing, notarization, and release verification.

This repository also provides the `MacStateCore` Swift library. Capsomnia uses a vendored copy of that library for shared state observations; MacReady's executable has no dependency on the app. See [compatibility](docs/compatibility.md).

## Related projects and author

- [Capsomnia](https://github.com/fuji-mak/Capsomnia): the Mac app that ties awake mode to Caps Lock.
- [cpsm — Capsomnia CLI & Skill](https://github.com/fuji-mak/cpsm): controls Capsomnia, including awake mode, timers, and settings. It requires Capsomnia 4.0.0+; the generally available 3.5.0 app does not include its CLI service.
- **MacReady**: observes the Mac's state and works independently.

Created by [Taketo Fujimaki](https://github.com/fuji-mak). Explore the author's profile for related work and contact information. Contributions and reports should include the command, macOS version, Mac model, and any unavailable fields relevant to the issue.

## Uninstall

Remove only the components you installed. If MacReady came from Capsomnia Tools, these commands leave `cpsm` and the `capsomnia` Skill in place.

```sh
sudo rm /usr/local/bin/macready
sudo rm /usr/local/share/macready/LICENSE
sudo rmdir /usr/local/share/macready
rm -r ~/.agents/skills/macready
rm ~/.claude/skills/macready
```

`rm ~/.claude/skills/macready` removes the compatibility link. `rmdir` leaves a non-empty directory intact if you added other files.

## Sources and known coverage

The readers use IOKit power-source APIs, IORegistry, CoreGraphics displays, Foundation thermal state, and read-only `pmset -g` output. Battery temperature interpretation follows [Apple's PowerManagement source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/AppleSmartBatteryManager/AppleSmartBattery.cpp) and [Smart Battery Data Specification 1.1](https://www.sbs-forum.org/specs/sbdat110.pdf). Thermal behavior is described by [Apple's ProcessInfo.ThermalState documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum).

Initial hardware validation is on the development Mac. Sensor availability varies by model and session; broader hardware and minimum-OS testing remain part of release review.
