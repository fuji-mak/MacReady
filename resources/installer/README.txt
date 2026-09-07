MacReady — Mac status CLI & Skill

macOS 13.5以降。Capsomniaアプリは不要です。
macreadyを /usr/local/bin/macready にインストールします。
ライセンス / License: /usr/local/share/macready/LICENSE
実行時点のMacの電源、バッテリー、温度、蓋などの状態を読み取ります。
Macの設定は変更しません。常駐や自動監視は行いません。

Skillは共通の内容です。Codex / Claude Code は導入先の選択です。
選んだ場所にログイン中のユーザー権限でインストールします。
  Codex: ~/.codex/skills/macready/SKILL.md
  Claude Code: ~/.claude/skills/macready/SKILL.md
同名のSkillがある場合は、このバージョンの内容に更新します。
Skillを使わない場合は両方の選択を外してください。

Requires macOS 13.5 or later. No Capsomnia app is required.
Installs macready in /usr/local/bin. Each run reads a fresh Mac status
snapshot; it does not change power settings or install a background agent.
Codex and Claude Code are destinations for the same optional Skill.
Selected Skills are installed for the logged-in user and replace existing
SKILL.md files at the listed paths. Deselect both to install only the CLI.

Author: Taketo Fujimaki
