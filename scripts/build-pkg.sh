#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="MacReady"
CLI="macready"
SKILL="macready"
LABEL="com.github.fuji-mak.macready.pkg"
VERSION="$(/usr/bin/tr -d '\r\n' < "$ROOT_DIR/VERSION")"
[[ "$VERSION" == <->.<->.<-> ]] || { echo "VERSION must be x.y.z" >&2; exit 1; }
DIST_DIR="${DIST_DIR:-${1:-$ROOT_DIR/dist}}"
APP_SIGN_ID="${APP_SIGN_ID:-Developer ID Application: Taketo Fujimaki (ZJZ8627852)}"
PKG_SIGN_ID="${PKG_SIGN_ID:-Developer ID Installer: Taketo Fujimaki (ZJZ8627852)}"
SKIP_SIGNING="${SKIP_SIGNING:-false}"
SKILL_SOURCE="$ROOT_DIR/skills/$SKILL/SKILL.md"
WORK_DIR="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$WORK_DIR"' EXIT
export COPYFILE_DISABLE=true

if [[ -z "${CLI_PATH:-}" ]]; then
  arch_names=(${=ARCHS:-arm64 x86_64})
  build_args=(--package-path "$ROOT_DIR" -c release)
  for arch_name in "${arch_names[@]}"; do
    [[ "$arch_name" == arm64 || "$arch_name" == x86_64 ]] || { echo "Unsupported ARCHS: $arch_name" >&2; exit 1; }
    build_args+=(--arch "$arch_name")
  done
  swift build "${build_args[@]}" --product "$CLI"
  CLI_PATH="$(swift build "${build_args[@]}" --show-bin-path)/$CLI"
fi
[[ -x "$CLI_PATH" && -f "$SKILL_SOURCE" ]] || { echo "Missing CLI binary or Skill source" >&2; exit 1; }
/bin/mkdir -p "$DIST_DIR/components" "$WORK_DIR/root/usr/local/bin" "$WORK_DIR/root/usr/local/share/$CLI" "$WORK_DIR/resources"
/usr/bin/install -m 0755 "$CLI_PATH" "$WORK_DIR/root/usr/local/bin/$CLI"
/usr/bin/install -m 0644 "$ROOT_DIR/LICENSE" "$WORK_DIR/root/usr/local/share/$CLI/LICENSE"
/usr/bin/xattr -cr "$WORK_DIR/root"
if [[ "$SKIP_SIGNING" == true ]]; then
  /usr/bin/codesign --force --sign - "$WORK_DIR/root/usr/local/bin/$CLI"
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" "$WORK_DIR/root/usr/local/bin/$CLI"
fi
/usr/bin/codesign --verify --strict "$WORK_DIR/root/usr/local/bin/$CLI"
/bin/mkdir -p "$DIST_DIR/bin"
/usr/bin/install -m 0755 "$WORK_DIR/root/usr/local/bin/$CLI" "$DIST_DIR/bin/$CLI"
/usr/bin/install -m 0644 "$ROOT_DIR/resources/installer/README.txt" "$WORK_DIR/resources/README.txt"

make_skill_pkg() {
  local destination="$1" receipt="$2" relative="$3"
  local scripts_dir="$WORK_DIR/$destination-scripts"
  local encoded="$(/usr/bin/base64 < "$SKILL_SOURCE" | /usr/bin/tr -d '\n')"
  /bin/mkdir -p "$scripts_dir"
  /usr/bin/install -m 0644 "$ROOT_DIR/scripts/install-skill-user.sh" "$scripts_dir/install-skill-user.sh"
  /usr/bin/install -m 0644 "$SKILL_SOURCE" "$scripts_dir/$SKILL-skill.md"
  /bin/cat > "$scripts_dir/postinstall" <<EOF
#!/bin/zsh
set -euo pipefail
console_user="\$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
if [[ -z "\$console_user" || "\$console_user" == root || "\$console_user" == _mbsetupuser ]]; then
  console_user="\${SUDO_USER:-}"
fi
if [[ -z "\$console_user" || "\$console_user" == root || "\$console_user" == *[!A-Za-z0-9._-]* ]]; then
  echo "Cannot determine the logged-in user for $SKILL Skill installation." >&2
  exit 1
fi
console_home="\$(/usr/bin/dscl . -read "/Users/\$console_user" NFSHomeDirectory 2>/dev/null | /usr/bin/sed -n 's/^NFSHomeDirectory: //p')"
if [[ -z "\$console_home" || "\$console_home" != /* || "\$console_home" == / ]]; then
  echo "Cannot determine the home directory for \$console_user." >&2
  exit 1
fi
script_dir="\$(cd "\$(dirname "\$0")" && pwd)"
/usr/bin/sudo -u "\$console_user" /bin/zsh -s -- "\$console_home" "$relative" "$SKILL" '$encoded' < "\$script_dir/install-skill-user.sh"
EOF
  /bin/chmod 0755 "$scripts_dir/postinstall"
  /usr/bin/pkgbuild --nopayload --scripts "$scripts_dir" --identifier "$LABEL.$receipt" --version "$VERSION" "$DIST_DIR/components/$CLI-$destination-skill.pkg"
}

/usr/bin/pkgbuild --root "$WORK_DIR/root" --ownership recommended --identifier "$LABEL.cli" --version "$VERSION" --install-location / "$DIST_DIR/components/$CLI-cli.pkg"
make_skill_pkg codex codex .codex/skills
make_skill_pkg claude claude-code .claude/skills

/bin/cat > "$WORK_DIR/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>$PRODUCT CLI &amp; Skill</title>
  <options customize="always" require-scripts="false" hostArchitectures="arm64,x86_64" />
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true" />
  <volume-check script="true">
    <allowed-os-versions><os-version min="13.5" /></allowed-os-versions>
  </volume-check>
  <readme file="README.txt" />
  <choices-outline>
    <line choice="cli" />
    <line choice="skills"><line choice="codex" /><line choice="claude" /></line>
  </choices-outline>
  <choice id="cli" title="$CLI CLI (required)" description="Install /usr/local/bin/$CLI." start_selected="true" enabled="false"><pkg-ref id="$LABEL.cli" /></choice>
  <choice id="skills" title="Skillをインストール / Install Skill" description="同じSkillの導入先を選択します。Choose destinations for the same Skill." start_selected="true" />
  <choice id="codex" title="Codex" description="~/.codex/skills/$SKILL" start_selected="true"><pkg-ref id="$LABEL.codex" /></choice>
  <choice id="claude" title="Claude Code" description="~/.claude/skills/$SKILL" start_selected="true"><pkg-ref id="$LABEL.claude-code" /></choice>
  <pkg-ref id="$LABEL.cli" version="$VERSION">$CLI-cli.pkg</pkg-ref>
  <pkg-ref id="$LABEL.codex" version="$VERSION">$CLI-codex-skill.pkg</pkg-ref>
  <pkg-ref id="$LABEL.claude-code" version="$VERSION">$CLI-claude-skill.pkg</pkg-ref>
</installer-gui-script>
EOF
/usr/bin/xmllint --noout "$WORK_DIR/distribution.xml"
/usr/bin/productbuild --distribution "$WORK_DIR/distribution.xml" --package-path "$DIST_DIR/components" --resources "$WORK_DIR/resources" "$WORK_DIR/unsigned.pkg"

# Inspect payloads without installing anything on this Mac.
/usr/bin/env -u COPYFILE_DISABLE /usr/sbin/pkgutil --expand-full "$WORK_DIR/unsigned.pkg" "$WORK_DIR/expanded"
/usr/bin/codesign --verify --strict "$WORK_DIR/expanded/$CLI-cli.pkg/Payload/usr/local/bin/$CLI"
/usr/bin/cmp -s "$ROOT_DIR/LICENSE" "$WORK_DIR/expanded/$CLI-cli.pkg/Payload/usr/local/share/$CLI/LICENSE"
for destination in codex claude; do
  /usr/bin/cmp -s "$SKILL_SOURCE" "$WORK_DIR/expanded/$CLI-$destination-skill.pkg/Scripts/$SKILL-skill.md"
done
VERSIONED_PKG="$DIST_DIR/$PRODUCT-$VERSION.pkg"
if [[ "$SKIP_SIGNING" == true ]]; then
  /usr/bin/install -m 0644 "$WORK_DIR/unsigned.pkg" "$VERSIONED_PKG"
else
  /usr/bin/productsign --sign "$PKG_SIGN_ID" "$WORK_DIR/unsigned.pkg" "$VERSIONED_PKG"
  /usr/sbin/pkgutil --check-signature "$VERSIONED_PKG"
fi
/usr/bin/install -m 0644 "$VERSIONED_PKG" "$DIST_DIR/$PRODUCT.pkg"
(cd "$DIST_DIR" && /usr/bin/shasum -a 256 "$PRODUCT-$VERSION.pkg" "$PRODUCT.pkg" > SHA256SUMS.txt)
echo "Built $VERSIONED_PKG (not notarized; not published)."
