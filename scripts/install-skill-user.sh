#!/bin/zsh
# Run only as the selected destination user, never as root.
set -euo pipefail
user_home="$1"
relative="$2"
skill_name="$3"
encoded="$4"
[[ "$EUID" -ne 0 ]] || { echo "Skill files must be written as the destination user." >&2; exit 1; }
skill_dir="$user_home/$relative/$skill_name"
if [[ -L "$skill_dir" || ( -e "$skill_dir" && ! -d "$skill_dir" ) ]]; then
  echo "Skill path is not a directory: $skill_dir" >&2
  exit 1
fi
/bin/mkdir -p "$skill_dir"
/usr/bin/printf '%s' "$encoded" | /usr/bin/base64 -D > "$skill_dir/SKILL.md"
/bin/chmod 0644 "$skill_dir/SKILL.md"
