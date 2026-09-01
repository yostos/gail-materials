#!/bin/bash -e
#
# Google Generative AI Leader 対策資料を HTML に変換する。
#
#   ./scripts/build-html.sh         全体を変換 (docs/index.adoc)
#   ./scripts/build-html.sh c3      章単体を変換 (docs/c3/index.adoc)

ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
DOC_NAME=gail
TARGET_PATH="${ROOT_PATH}/build/html"

if [ -n "$1" ]; then
  SOURCE="${ROOT_PATH}/docs/$1/index.adoc"
  OUTPUT="${TARGET_PATH}/${DOC_NAME}-$1.html"
else
  SOURCE="${ROOT_PATH}/docs/index.adoc"
  OUTPUT="${TARGET_PATH}/${DOC_NAME}.html"
fi

if [ ! -f "${SOURCE}" ]; then
  echo ">> ERROR: ${SOURCE} が見つかりません。" >&2
  exit 1
fi

# CI からバージョン・日付などの属性を注入するための口。
#   ASCIIDOC_ATTRS="-a revnumber=1.0.0 -a revdate=2026-09-01" ./scripts/build-pdf.sh
# shellcheck disable=SC2206
EXTRA_ATTRS=(${ASCIIDOC_ATTRS:-})

mkdir -p "${TARGET_PATH}"

echo ">> Converting AsciiDoc to HTML: ${SOURCE#"${ROOT_PATH}"/}"

# data-uri で画像を埋め込み、HTML 1ファイルで持ち運べるようにする。
asciidoctor \
  -a data-uri \
  -r asciidoctor-diagram \
  "${EXTRA_ATTRS[@]}" \
  "${SOURCE}" \
  -o "${OUTPUT}"

echo ">> Convert succeeded!"
ls -lh "${OUTPUT}"
