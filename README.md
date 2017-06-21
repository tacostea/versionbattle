# versionbattle
鯖缶御用達の新バージョン追従バトルを観測するやつ

## つかいかた
1. とりあえず使いたい
```bash
$ ./version.sh
<バージョン番号> <インスタンス名>
<バージョン番号> <インスタンス名>
<バージョン番号> <インスタンス名>
.
.
.
```
パイプしてsortするもよし、保存してムフフするもよし。

2. おなじみのインスタンスとversionbattleしたい
まず対象インスタンス名の書かれたinstances.listを用意します。
とりあえずinstances.mastodon.xyzのものを使いたい場合はこれで。
```bash
curl -s https://instances.mastodon.xyz/instances.json | jq -r '.[].name' > instances.list
```
instances.listが用意できたらこれ。
```bash
$ ./version.sh
```
実行するコマンドは同じでも、結果はresults.txtに残る。(標準出力されない)

