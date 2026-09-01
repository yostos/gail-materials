#!/bin/bash -e
#
# PDF に埋め込む BIZ UDGothic を取得して build/fonts/ に配置する。
# フォントは取得物であってソースではないため、リポジトリには含めていない。
#
#   ./scripts/fetch-fonts.sh          未取得なら取得する
#   ./scripts/fetch-fonts.sh --force  既にあっても取り直す
#
# 取得元のコミットは FONTS_REF で上書きできる。

ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
FONTS_PATH="${ROOT_PATH}/build/fonts"

# google/fonts のコミットに固定する。main を追うとビルドの再現性が失われる。
FONTS_REF="${FONTS_REF:-6ce172f74aa355ea43eb964fa4a91570a4d3064d}"
BASE_URL="https://raw.githubusercontent.com/google/fonts/${FONTS_REF}/ofl/bizudgothic"

# themes/mystyle-theme.yml が参照するウェイトと、同梱が求められるライセンス。
FILES=(BIZUDGothic-Regular.ttf BIZUDGothic-Bold.ttf OFL.txt)

if [ "$1" != "--force" ]; then
  missing=0
  for f in "${FILES[@]}"; do
    [ -f "${FONTS_PATH}/${f}" ] || missing=1
  done
  if [ "${missing}" -eq 0 ]; then
    echo ">> Fonts already present. Use --force to re-download."
    exit 0
  fi
fi

if ! command -v curl >/dev/null 2>&1; then
  echo ">> ERROR: curl が見つかりません。" >&2
  exit 1
fi

mkdir -p "${FONTS_PATH}"

# 途中で失敗したファイルを残さないよう、一時ディレクトリに揃えてから移す。
WORK_PATH="$(mktemp -d)"
trap 'rm -rf "${WORK_PATH}"' EXIT

for f in "${FILES[@]}"; do
  echo ">> Downloading ${f}"
  curl -fsSL --retry 3 -o "${WORK_PATH}/${f}" "${BASE_URL}/${f}"
done

mv "${WORK_PATH}"/* "${FONTS_PATH}/"

echo ">> Fetch succeeded!"
ls -lh "${FONTS_PATH}"
