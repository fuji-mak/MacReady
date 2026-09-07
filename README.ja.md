# MacReady

AIエージェントに、Macの電源・バッテリー・熱・蓋・スリープ設定の現在値を届けるCLIとSkillです。

[Taketo Fujimaki](https://github.com/fuji-mak)が開発する、読み取り専用の小さなmacOSツールです。コマンドを実行するたびに取得時刻付きの状態を返し、長時間の作業についてエージェントと判断する材料にできます。

[English](README.md) · [変更履歴](CHANGELOG.md) · [配布準備](docs/releasing.md) · [MITライセンス](LICENSE)

> **v0.1.0は2026年9月8日に公開した初回リリースです。** MacReadyはCapsomniaを必要としない、単独利用可能なツールです。

[MacReady.pkgをダウンロード](https://github.com/fuji-mak/MacReady/releases/latest/download/MacReady.pkg)

```sh
macready status --json
```

## 読み取れるもの

- 電源種別、バッテリーの有無・残量・充電中かどうか。
- バッテリー温度とmacOSの熱状態。
- 蓋、外部ディスプレイ、システム全体の`SleepDisabled`設定。
- 取得時刻と、取得できなかった項目の理由。

Capsomniaアプリ、実行時のsudo、常駐、外部通信は不要です。設定の変更や作業継続の自動判定は行いません。各コマンドは1回読み取って終了します。

## インストール

**macOS 13.5以降**が必要です。MacReady 0.1.0のパッケージはApple silicon／Intelの
universal binaryです。

[`MacReady.pkg`](https://github.com/fuji-mak/MacReady/releases/latest/download/MacReady.pkg)を開きます。

| 内容 | 配置先 |
| --- | --- |
| 必須CLI | `/usr/local/bin/macready` |
| 任意のCodex用Skill | `~/.codex/skills/macready/SKILL.md` |
| 任意のClaude Code用Skill | `~/.claude/skills/macready/SKILL.md` |

Skill本文は同じで、CodexとClaude Codeは配置先の選択です。インストール時は`/usr/local/bin`への書き込みのため管理者認証が必要ですが、実行時は不要です。SkillはMacのコンソールセッションにログインしているユーザーのホームに配置します。

Capsomniaの詳細設定から取得する[**Capsomnia Tools**](https://github.com/fuji-mak/cpsm/releases/latest/download/Capsomnia-Tools.pkg)にも、
`cpsm`と両方のSkillと一緒に含まれます。Capsomniaアプリ本体のpkgとは別の配布物です。

## 使い方

```sh
macready                    # 人が読む形式
macready status --json      # エージェントやスクリプト用
macready --help
macready --version
```

Skill導入後は、エージェントに「今のMacの電源と熱の状態を教えて」などと依頼できます。エージェントがMac上のコマンドを実行できる環境が必要です。Skillだけで遠隔端末とMacが接続されるわけではありません。

JSONの全体例は[英語README](README.md)にあります。

| フィールド | 意味と制約 |
| --- | --- |
| `power.source` | `ac` / `battery` / `ups` / `unknown`。AC接続と充電中は別です。 |
| `power.battery_present` | バッテリーの有無。`battery_percent`は残量、`charging`は充電中かどうかです。 |
| `thermal_state` | `nominal` / `fair` / `serious` / `critical` / `unknown`。macOSは非対応・不明時にも`nominal`を返しうるため、安全の保証ではありません。 |
| `temperature.battery_celsius` | バッテリー温度です。IORegistryの`Temperature`をSmart Battery形式の0.1 Kとして`raw / 10 - 273.15`で℃へ換算します。安定した公開APIではないため、生値と出典名も返します。 |
| `temperature.cpu_celsius` / `gpu_celsius` | 0.1では未対応のため常に`null`です。 |
| `lid_closed` / `external_display_connected` | 蓋・外部ディスプレイの観測結果。取得不能時は`null`です。蓋のないMacでは蓋の値を取得できない場合があります。 |
| `sleep_disabled` | `pmset -g`が返すシステム全体の`SleepDisabled`です。個別プロセスのsleep assertionや蓋を閉じたときの作業継続を保証しません。 |
| `unavailable` | 取得不能項目の理由。バッテリー非搭載時の残量・充電値の`null`は非該当です。 |

JSONは`schema_version: 1`で、取得時刻は`captured_at`にUTCで出力します。欠損値は`null` / `unknown`のまま返します。利用側はschema versionを確認し、追加フィールドを許容してください。現在値が必要なときは再実行します。常時監視や残り作業時間の推定はしません。

終了コードは、**0**がスナップショット・ヘルプ・バージョン出力、**2**が引数エラー、**1**がスナップショットのエンコード失敗です。0でも取得不能項目を含むことがあります。`--json`指定時の引数エラーは`ok: false`と`error`を含むJSONです。

## ソースからビルド

macOS SDKとSwift 5.9以降（Xcodeまたは対応するCommand Line Tools）が必要です。

```sh
swift build -c release --product macready
.build/release/macready status --json
swift test

# ローカル確認用。CLIはad hoc署名となり、そのまま公開するpkgではありません。
SKIP_SIGNING=true ./scripts/build-pkg.sh
```

パッケージスクリプトは標準で両アーキテクチャをビルドし、`dist/MacReady-0.1.0.pkg`、`dist/MacReady.pkg`、`dist/SHA256SUMS.txt`を生成します。署名・公証・公開前確認は[配布準備](docs/releasing.md)を参照してください。

`MacStateCore`ライブラリもこのリポジトリに含みます。Capsomniaはそのコピーを取り込んで状態読み取りを共有しますが、MacReadyの実行にはCapsomniaは必要ありません。[互換性](docs/compatibility.md)も参照してください。

## 関連作品・作者

- [Capsomnia](https://github.com/fuji-mak/Capsomnia)：Caps Lockとスリープ抑止を結び付けるMacアプリ。
- [**cpsm — Capsomnia CLI & Skill**](https://github.com/fuji-mak/cpsm)：Capsomniaのスリープ抑止・タイマー・設定を操作するツール。Capsomnia 4.0.0以降が必要で、一般公開中の3.5.0にはCLIの受付機能がありません。
- **MacReady**：Macの状態を観測する、単独で動くツール。

作者：[Taketo Fujimaki](https://github.com/fuji-mak)。関連作品や連絡先はプロフィールから確認できます。不具合の報告では、コマンド、macOSのバージョン、Macの機種、関係する取得不能項目を添えてください。

## アンインストール

導入した項目だけ削除します。Capsomnia Toolsから導入した場合も、以下では`cpsm`と`capsomnia` Skillを残します。

```sh
sudo rm /usr/local/bin/macready
rm ~/.codex/skills/macready/SKILL.md
rmdir ~/.codex/skills/macready
rm ~/.claude/skills/macready/SKILL.md
rmdir ~/.claude/skills/macready
```

導入していない配置先のコマンドは省いてください。`rmdir`は、追加したファイルがあるディレクトリを削除しません。

## 根拠と確認範囲

電源はIOKit、温度・蓋はIORegistry、ディスプレイはCoreGraphics、熱状態はFoundation、スリープ設定は読み取り専用の`pmset -g`を使用します。温度の形式は[Apple公開PowerManagementソース](https://github.com/apple-oss-distributions/PowerManagement/blob/main/AppleSmartBatteryManager/AppleSmartBattery.cpp)と[Smart Battery Data Specification 1.1](https://www.sbs-forum.org/specs/sbdat110.pdf)、熱状態は[Apple公式ドキュメント](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum)を根拠としています。

初期の実機確認は開発中のMacで行っています。センサーの取得可否は機種・セッションにより異なり、他機種と最小対応OSでの確認は公開前の確認項目です。
