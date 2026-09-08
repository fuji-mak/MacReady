#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
installer="$script_dir/install-skill-user.sh"
tmp_home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/shared-skill-test.XXXXXX")"
trap '/bin/rm -rf "$tmp_home"' EXIT
skill='test skill v1'
encoded="$(/usr/bin/printf '%s' "$skill" | /usr/bin/base64 | /usr/bin/tr -d '\n')"

run_install() {
  /bin/zsh "$installer" "$tmp_home" macready "$encoded"
}

run_install
[[ "$(/bin/cat "$tmp_home/.agents/skills/macready/SKILL.md")" == "$skill" ]]
[[ "$(/usr/bin/readlink "$tmp_home/.claude/skills/macready")" == "$tmp_home/.agents/skills/macready" ]]

# A modified managed Skill is rejected unchanged, then a new version is accepted.
printf '%s' changed > "$tmp_home/.agents/skills/macready/SKILL.md"
if run_install 2>/dev/null; then exit 1; fi
[[ "$(/bin/cat "$tmp_home/.agents/skills/macready/SKILL.md")" == changed ]]
printf '%s' 'test skill v1' > "$tmp_home/.agents/skills/macready/SKILL.md"
skill='test skill v1'
encoded="$(/usr/bin/printf '%s' "$skill" | /usr/bin/base64 | /usr/bin/tr -d '\n')"
run_install
skill='test skill v2'
encoded="$(/usr/bin/printf '%s' "$skill" | /usr/bin/base64 | /usr/bin/tr -d '\n')"
run_install
[[ "$(/bin/cat "$tmp_home/.agents/skills/macready/SKILL.md")" == "$skill" ]]

# An old, identical Codex copy is migrated.
rm "$tmp_home/.claude/skills/macready"
mkdir -p "$tmp_home/.codex/skills/macready"
printf '%s' "$skill" > "$tmp_home/.codex/skills/macready/SKILL.md"
run_install
[[ ! -e "$tmp_home/.codex/skills/macready" ]]
[[ -L "$tmp_home/.claude/skills/macready" ]]
run_install

# Custom content remains untouched and blocks replacement.
rm "$tmp_home/.claude/skills/macready"
mkdir -p "$tmp_home/.claude/skills/macready"
printf '%s' custom > "$tmp_home/.claude/skills/macready/SKILL.md"
if run_install 2>/dev/null; then exit 1; fi
[[ "$(/bin/cat "$tmp_home/.claude/skills/macready/SKILL.md")" == custom ]]

# A conflict in the legacy Claude path leaves an initially absent canonical path untouched.
rm -rf "$tmp_home/.agents/skills/macready" "$tmp_home/.claude/skills/macready"
mkdir -p "$tmp_home/.claude/skills/macready"
printf '%s' conflict > "$tmp_home/.claude/skills/macready/SKILL.md"
if run_install 2>/dev/null; then exit 1; fi
[[ ! -e "$tmp_home/.agents/skills/macready" ]]
[[ "$(/bin/cat "$tmp_home/.claude/skills/macready/SKILL.md")" == conflict ]]

# A foreign ancestor symlink is rejected without being traversed.
rm -rf "$tmp_home/.claude/skills/capsomnia" "$tmp_home/.codex"
mkdir -p "$tmp_home/.codex" "$tmp_home/foreign"
ln -s "$tmp_home/foreign" "$tmp_home/.codex/skills"
if run_install 2>/dev/null; then exit 1; fi

print "shared skill installer tests passed"
