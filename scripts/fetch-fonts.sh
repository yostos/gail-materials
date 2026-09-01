#!/bin/bash -e
#
# PDF に埋め込む更紗ゴシック（Sarasa Mono J）を取得して fonts/ に配置する。
# フォントはサイズが大きいためリポジトリには含めていない。
#
#   ./scripts/fetch-fonts.sh          未取得なら取得する
#   ./scripts/fetch-fonts.sh --force  既にあっても取り直す
#
# 取得するバージョンは SARASA_VERSION で上書きできる。

ROOT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
FONTS_PATH="${ROOT_PATH}/fonts"
SARASA_VERSION="${SARASA_VERSION:-1.0.41}"
ARCHIVE="SarasaMonoJ-TTF-${SARASA_VERSION}.7z"
URL="https://github.com/be5invis/Sarasa-Gothic/releases/download/v${SARASA_VERSION}/${ARCHIVE}"

# themes/mystyle-theme.yml が参照する4ウェイトだけを配置する。
# アーカイブ内の名前 -> fonts/ での名前
FACES=(
  "SarasaMonoJ-Regular.ttf:sarasa-mono-j-regular.ttf"
  "SarasaMonoJ-Italic.ttf:sarasa-mono-j-italic.ttf"
  "SarasaMonoJ-Bold.ttf:sarasa-mono-j-bold.ttf"
  "SarasaMonoJ-BoldItalic.ttf:sarasa-mono-j-bolditalic.ttf"
)

if [ "$1" != "--force" ]; then
  missing=0
  for face in "${FACES[@]}"; do
    [ -f "${FONTS_PATH}/${face#*:}" ] || missing=1
  done
  if [ "${missing}" -eq 0 ]; then
    echo ">> Fonts already present. Use --force to re-download."
    exit 0
  fi
fi

for cmd in curl 7z; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo ">> ERROR: ${cmd} が見つかりません。" >&2
    [ "${cmd}" = "7z" ] && echo ">>        macOS: brew install p7zip / Debian: apt install p7zip-full" >&2
    exit 1
  fi
done

WORK_PATH="$(mktemp -d)"
trap 'rm -rf "${WORK_PATH}"' EXIT

echo ">> Downloading ${ARCHIVE}"
curl -fsSL --retry 3 -o "${WORK_PATH}/${ARCHIVE}" "${URL}"

echo ">> Extracting"
# 必要な4ファイルだけを展開する。アーカイブ全体は展開しない。
( cd "${WORK_PATH}" && 7z x -bso0 -bsp0 "${ARCHIVE}" "${FACES[@]%%:*}" )

mkdir -p "${FONTS_PATH}"
for face in "${FACES[@]}"; do
  src="${WORK_PATH}/${face%%:*}"
  if [ ! -f "${src}" ]; then
    echo ">> ERROR: アーカイブに ${face%%:*} が見つかりません。" >&2
    exit 1
  fi
  mv "${src}" "${FONTS_PATH}/${face#*:}"
done

echo ">> Fetch succeeded!"
ls -lh "${FONTS_PATH}"
