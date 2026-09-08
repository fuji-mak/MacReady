MacReady — Mac status CLI & Skill

macOS 13.5以降。Capsomniaアプリは不要です。
macreadyを /usr/local/bin/macready にインストールします。
ライセンス / License: /usr/local/share/macready/LICENSE
実行時点のMacの電源、バッテリー、温度、蓋などの状態を読み取ります。
Macの設定は変更しません。常駐や自動監視は行いません。

Skillは共通の内容で、ログイン中のユーザーへ自動導入します。
ログイン中のユーザー権限で共通先へインストールします。
  共通: ~/.agents/skills/macready/SKILL.md
  Claude Code: ~/.claude/skills/macready -> 共通Skillへのsymlink
同名のSkillがある場合は、このバージョンの内容に更新します。
旧版の同一内容だけを安全に移行します。カスタム内容は保持し、競合時は停止します。

Requires macOS 13.5 or later. No Capsomnia app is required.
Installs macready in /usr/local/bin. Each run reads a fresh Mac status
snapshot; it does not change power settings or install a background agent.
Codex and Claude Code use one shared Skill installation.
The Skill is installed at ~/.agents/skills/macready and Claude Code receives
a symlink at ~/.claude/skills/macready. Existing identical legacy copies are
migrated; custom or conflicting content is preserved and causes the installer
to stop.

Author: Taketo Fujimaki
