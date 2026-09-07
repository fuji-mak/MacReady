---
name: macready
description: Read the local Mac's power, battery, thermal, lid, display, and sleep prevention state with macready when the user asks about Mac conditions or whether a long-running task can continue.
---

Use `macready status --json` to obtain a fresh snapshot. Find the executable on PATH or at `/usr/local/bin/macready`; for a local preview, use the path supplied by the user. Capsomnia is not required. If the CLI is missing, explain that MacReady needs installation.

Report observations with their timestamp. Missing values (`null`, `unknown`, or entries in `unavailable`) are not evidence of a safe or normal condition. A successful exit means the snapshot was produced; some observations may be unavailable. Distinguish AC power from actively charging. `sleep_disabled` is only the system-wide SleepDisabled setting, not a list of all sleep assertions or a guarantee that a task will survive lid closure.

`temperature.battery_celsius` measures the battery, not the CPU/GPU. Its underlying IORegistry property is not a stable public API; the raw value and source are included. CPU/GPU temperatures are unsupported in MacReady 0.1 and remain null.

`thermal_state` is macOS's reported nominal/fair/serious/critical state, not a CPU temperature or a safety certification. macOS can also report nominal when its thermal state is unsupported or unknown. Judge continued work in context of the task, power source, battery level and heat observations; do not invent universal temperature limits or a guaranteed remaining runtime.

MacReady observes only. Do not change power settings, stop jobs, or put the Mac to sleep based solely on a snapshot. When the user requests a Capsomnia control operation, use its `capsomnia` Skill / `cpsm` CLI separately. Do not assume MacReady installed Capsomnia. Each invocation exits after reading; ongoing monitoring requires an explicitly requested follow-up mechanism in the agent's environment.
