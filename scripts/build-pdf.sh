#!/bin/bash -e
#
# Google Generative AI Leader 対策資料を PDF に変換する。
#
#   ./scripts/build-pdf.sh          全体を変換 (docs/index.adoc)
#   ./scripts/build-pdf.sh c3       章単体を変換 (docs/c3/index.adoc)

ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
DOC_NAME=gail
TARGET_PATH="${ROOT_PATH}/build/pdf"

if [ -n "$1" ]; then
  SOURCE="${ROOT_PATH}/docs/$1/index.adoc"
  OUTPUT="${TARGET_PATH}/${DOC_NAME}-$1.pdf"
else
  SOURCE="${ROOT_PATH}/docs/index.adoc"
  OUTPUT="${TARGET_PATH}/${DOC_NAME}.pdf"
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

echo ">> Converting AsciiDoc to PDF: ${SOURCE#"${ROOT_PATH}"/}"

# 日本語の行分割(scripts=cjk)と更紗フォント埋め込み(themes/fonts)を有効にする。
# unbreakable-tables.rb は表のページ跨ぎ分断を防ぐ拡張。
asciidoctor-pdf \
  -a scripts=cjk \
  -a pdf-theme=mystyle-theme.yml \
  -a pdf-themesdir="${ROOT_PATH}/themes" \
  -a pdf-fontsdir="${ROOT_PATH}/fonts" \
  -r asciidoctor-diagram \
  -r "${ROOT_PATH}/scripts/unbreakable-tables.rb" \
  "${EXTRA_ATTRS[@]}" \
  "${SOURCE}" \
  -o "${OUTPUT}"

echo ">> Convert succeeded!"
ls -lh "${OUTPUT}"
