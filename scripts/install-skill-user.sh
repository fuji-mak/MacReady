#!/bin/zsh
# Run only as the selected destination user, never as root.
set -euo pipefail

user_home="$1"
skill_name="$2"
encoded="$3"
[[ "$EUID" -ne 0 ]] || { echo "Skill files must be written as the destination user." >&2; exit 1; }
[[ "$user_home" == /* && "$user_home" != / && "$skill_name" != */* && "$skill_name" != .* ]] || {
  echo "Invalid Skill installation arguments." >&2; exit 1
}

tmp_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/skill-install.XXXXXX")"
tmp_meta="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/skill-install-meta.XXXXXX")"
trap '/bin/rm -f "$tmp_file" "$tmp_meta"' EXIT
/usr/bin/printf '%s' "$encoded" | /usr/bin/base64 -D > "$tmp_file"
/bin/chmod 0644 "$tmp_file"
incoming_hash="$(/usr/bin/shasum -a 256 "$tmp_file" | /usr/bin/awk '{print $1}')"
/usr/bin/printf '%s\n' "$incoming_hash" > "$tmp_meta"
/bin/chmod 0644 "$tmp_meta"

canonical="$user_home/.agents/skills/$skill_name"
claude_dir="$user_home/.claude/skills/$skill_name"
codex_dir="$user_home/.codex/skills/$skill_name"
meta_name=".capsomnia-managed-sha256"
[[ "$skill_name" == macready ]] && meta_name=".macready-managed-sha256"

assert_no_foreign_ancestor() {
  local path="$1" cur="$user_home" part
  local rel="${path#$user_home/}"
  for part in ${(s:/:)rel}; do
    cur="$cur/$part"
    [[ "$cur" == "$path" ]] && break
    [[ -L "$cur" ]] && { echo "Refusing to traverse foreign Skill symlink: $cur" >&2; exit 1; }
  done
}
assert_no_foreign_ancestor "$canonical"
assert_no_foreign_ancestor "$codex_dir"
assert_no_foreign_ancestor "$claude_dir"

is_legacy_identical() {
  local dir="$1" entry
  [[ -d "$dir" && ! -L "$dir" && -f "$dir/SKILL.md" && ! -L "$dir/SKILL.md" ]] || return 1
  while IFS= read -r -d '' entry; do
    [[ "${entry##*/}" == SKILL.md ]] || return 1
  done < <(/usr/bin/find -H "$dir" -mindepth 1 -maxdepth 1 -print0)
  /usr/bin/cmp -s "$tmp_file" "$dir/SKILL.md"
}

is_managed_canonical() {
  local dir="$1" entry expected
  [[ -d "$dir" && ! -L "$dir" && -f "$dir/SKILL.md" && ! -L "$dir/SKILL.md" ]] || return 1
  [[ -f "$dir/$meta_name" && ! -L "$dir/$meta_name" ]] || return 1
  while IFS= read -r -d '' entry; do
    [[ "${entry##*/}" == SKILL.md || "${entry##*/}" == "$meta_name" ]] || return 1
  done < <(/usr/bin/find -H "$dir" -mindepth 1 -maxdepth 1 -print0)
  expected="$(/usr/bin/tr -d '[:space:]' < "$dir/$meta_name")"
  [[ "$expected" == "$(/usr/bin/shasum -a 256 "$dir/SKILL.md" | /usr/bin/awk '{print $1}')" ]]
}

# Complete preflight. No canonical or legacy path is mutated until every
# existing path has been checked.
canonical_state=absent
if [[ -L "$canonical" || ( -e "$canonical" && ! -d "$canonical" ) ]]; then
  echo "Canonical Skill path is not a directory: $canonical" >&2
  exit 1
elif [[ -e "$canonical" ]]; then
  if is_managed_canonical "$canonical"; then
    canonical_state=managed
  elif is_legacy_identical "$canonical"; then
    canonical_state=legacy-identical
  else
    echo "Refusing to replace a custom or conflicting Skill directory: $canonical" >&2
    exit 1
  fi
fi

preflight_old() {
  local old="$1"
  if [[ -L "$old" ]]; then
    [[ "$(/usr/bin/readlink "$old")" == "$canonical" ]] || {
      echo "Refusing to replace foreign Skill symlink: $old" >&2
      exit 1
    }
    return
  fi
  [[ -e "$old" ]] || return 0
  is_legacy_identical "$old" || {
    echo "Refusing to replace a custom or conflicting Skill directory: $old" >&2
    exit 1
  }
}
preflight_old "$codex_dir"
if [[ -L "$claude_dir" ]]; then
  [[ "$(/usr/bin/readlink "$claude_dir")" == "$canonical" ]] || {
    echo "Refusing to replace foreign Claude Skill symlink: $claude_dir" >&2
    exit 1
  }
elif [[ -e "$claude_dir" ]]; then
  is_legacy_identical "$claude_dir" || {
    echo "Refusing to replace a custom or conflicting Skill directory: $claude_dir" >&2
    exit 1
  }
fi

# Apply only after preflight succeeds.
if [[ "$canonical_state" == absent ]]; then
  /bin/mkdir -p "${canonical:h}"
  /bin/mkdir "$canonical"
elif [[ "$canonical_state" == legacy-identical ]]; then
  : # The old published layout has no metadata; add it below.
fi
/usr/bin/install -m 0644 "$tmp_file" "$canonical/SKILL.md"
/usr/bin/install -m 0644 "$tmp_meta" "$canonical/$meta_name"

if [[ -d "$codex_dir" && ! -L "$codex_dir" ]]; then
  /bin/rm -f "$codex_dir/SKILL.md"
  /bin/rmdir "$codex_dir"
fi
if [[ -d "$claude_dir" && ! -L "$claude_dir" ]]; then
  /bin/rm -f "$claude_dir/SKILL.md"
  /bin/rmdir "$claude_dir"
fi
if [[ ! -e "$claude_dir" && ! -L "$claude_dir" ]]; then
  /bin/mkdir -p "${claude_dir:h}"
  /bin/ln -s "$canonical" "$claude_dir"
fi
