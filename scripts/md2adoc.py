#!/usr/bin/env python3
"""学習ノート(Markdown)を AsciiDoc に変換して docs/ 配下へ書き出す。

  ./scripts/md2adoc.py                既定のソースから変換
  ./scripts/md2adoc.py path/to/note.md   ソースを指定して変換

docs/ 配下の .adoc はこのスクリプトの生成物。ノート側を直して再生成する運用なら、
docs/ の手編集は上書きされる点に注意する。章・節の分割単位、明示アンカー、
xref の対応表は下の定数で管理する。
"""
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.expanduser("~/mulmoclaude/artifacts/documents/2026/08/gail-notes.md")
DST = os.path.join(ROOT, "docs")

# 章 → (ディレクトリ, 章タイトル)
CHAPTERS = {
    "0": ("c0", "この試験について"),
    "1": ("c1", "生成AIの基礎"),
    "2": ("c2", "Google Cloud の生成AI製品"),
    "3": ("c3", "出力の改善技法"),
    "4": ("c4", "ビジネス戦略と責任あるAI"),
}

# 節番号 → ファイル basename（章1〜4のみ分割する）
SECTION_FILES = {
    "1.1": "what-is-genai",
    "1.2": "ml-learning-types",
    "1.3": "adjacent-concepts",
    "1.4": "ml-lifecycle",
    "1.5": "data-quality-and-labels",
    "1.6": "model-families",
    "1.7": "model-selection-criteria",
    "1.8": "generative-architectures",
    "1.9": "agents",
    "1.10": "limitations",
    "2.1": "product-layers",
    "2.2": "ai-infrastructure",
    "2.3": "data-foundation",
    "2.4": "vertex-ai",
    "2.5": "prompt-playgrounds",
    "2.6": "gemini-for-google-cloud",
    "2.7": "gemini-enterprise-and-search",
    "2.8": "customer-engagement-suite",
    "2.9": "end-user-tools",
    "2.10": "task-specific-apis",
    "3.1": "technique-selection",
    "3.2": "prompt-design",
    "3.3": "generation-parameters",
    "3.4": "grounding-and-rag",
    "3.5": "embeddings",
    "3.6": "monitoring-and-evaluation",
    "4.1": "adoption-strategy",
    "4.2": "responsible-ai",
    "4.3": "explainability",
    "4.4": "secure-ai",
}

# 相互参照の対象になる見出しへ付ける明示アンカー
ANCHORS = {
    "1.9": "agents",
    "1.10.2": "data-dependency",
    "2.3.1": "data-types",
    "2.4.1": "model-garden",
    "3.2.2": "role-prompting",
    "3.2.4": "chain-of-thought",
    "3.4": "grounding-and-rag",
    "4.1.5": "rule-based-processing",
    "4.4.3": "data-protection-layers",
}

# 本文中の節番号参照 → xref
XREFS = {
    "（3.2.4）": "（<<chain-of-thought>>）",
    "（4.1.5）": "（<<rule-based-processing>>）",
    "（2.3.1）": "（<<data-types>>）",
    "（1.10.2）": "（<<data-dependency>>）",
    "（2.4.1）": "（<<model-garden>>）",
    "（3.4）": "（<<grounding-and-rag>>）",
    "（3.2.2）": "（<<role-prompting>>）",
    "（1.9）": "（<<agents>>）",
    "4.4.3 の表": "<<data-protection-layers>> の表",
}

APPENDICES = {
    "A": ("usecase-lookup", "用途からの逆引き"),
    "B": ("gcp-aws-mapping", "GCP↔AWS 対比表"),
}


def dwidth(s):
    """全角を2、半角を1として文字列の表示幅を返す。"""
    return sum(2 if unicodedata.east_asian_width(c) in "WFA" else 1 for c in s)


def inline(text):
    """インライン記法を Markdown から AsciiDoc へ変換する。"""
    # [表示文字列](URL) → link:URL[表示文字列]
    # 直前が CJK 文字だと素の URL マクロは認識されないため link: を必ず付ける。
    text = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r"link:\2[\1]", text)
    # 強調は **...** のまま残す。AsciiDoc の制約付き強調 *...* は
    # 前後が日本語だと解釈されず、アスタリスクがそのまま出てしまう。
    for src, dst in XREFS.items():
        text = text.replace(src, dst)
    return text


def convert_table(rows):
    """Markdown の表を AsciiDoc の表に変換する。"""
    cells = []
    for row in rows:
        body = row.strip()
        body = body[1:] if body.startswith("|") else body
        body = body[:-1] if body.endswith("|") else body
        cells.append([c.strip() for c in body.split("|")])
    header, body = cells[0], cells[2:]  # cells[1] は区切り行

    ncol = max(len(r) for r in cells)
    header += [""] * (ncol - len(header))
    body = [r + [""] * (ncol - len(r)) for r in body]

    # 列幅は各列の最大表示幅から比率を求める。1〜5 に収める。
    widths = [max(dwidth(r[i]) for r in [header] + body) or 1 for i in range(ncol)]
    base = min(widths)
    cols = [max(1, min(5, round(w / base))) for w in widths]

    out = ['[cols="%s", options="header"]' % ",".join(str(c) for c in cols), "|==="]
    out.append(" ".join("| " + inline(c) for c in header))
    out.append("")
    for r in body:
        out.append(" ".join("| " + inline(c) for c in r))
    out.append("|===")
    return out


def convert_body(lines):
    """見出しを除く本文を変換する。"""
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(lines[i])
                i += 1
            out.extend(convert_table(rows))
            continue
        if line.startswith("- 出典:"):
            # 出典は箇条書きではなく段落にする（直前のリストと融合させないため）。
            out.append(inline(line[2:]))
            i += 1
            continue
        out.append(inline(line))
        i += 1
    # 末尾の空行を落とす
    while out and not out[-1].strip():
        out.pop()
    return out


def parse(path):
    """Markdown を見出し単位のツリーへ分解する。"""
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")

    doc = {"lead": [], "chapters": []}
    cur_ch = cur_sec = None
    for line in lines:
        m = re.match(r"^(#{1,4}) (.+)$", line)
        if not m:
            target = doc["lead"]
            if cur_ch is not None:
                target = cur_ch["lead"]
                if cur_sec is not None:
                    target = cur_sec["subs"][-1]["body"] if cur_sec["subs"] else cur_sec["body"]
            target.append(line)
            continue
        level, title = len(m.group(1)), m.group(2).strip()
        if level == 1:
            doc["title"] = title
        elif level == 2:
            cur_ch = {"raw": title, "lead": [], "secs": []}
            doc["chapters"].append(cur_ch)
            cur_sec = None
        elif level == 3:
            cur_sec = {"raw": title, "body": [], "subs": []}
            cur_ch["secs"].append(cur_sec)
        else:
            cur_sec["subs"].append({"raw": title, "body": []})
    return doc


def split_num(raw):
    """「1.10 生成AIの制限事項」→ ("1.10", "生成AIの制限事項")"""
    m = re.match(r"^([0-9][0-9.]*)\.?\s+(.+)$", raw)
    if m:
        return m.group(1).rstrip("."), m.group(2)
    m = re.match(r"^付録([AB])\s*(.+)$", raw)
    if m:
        return "付録" + m.group(1), m.group(2)
    return None, raw


def heading(level, num, title):
    """アンカー付きの見出し行を返す。"""
    out = []
    if num in ANCHORS:
        out.append("[#%s]" % ANCHORS[num])
    out.append("=" * level + " " + title)
    return out


def write(path, lines):
    # 連続する空行は1行にまとめる。
    squeezed = []
    for line in lines:
        if not line.strip() and squeezed and not squeezed[-1].strip():
            continue
        squeezed.append(line)
    lines = squeezed
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")
    print("wrote %s (%d lines)" % (path, len(lines)))


def emit_section(sec, depth):
    """節（###）とその小節（####）を、指定レベル起点で出力する。"""
    num, title = split_num(sec["raw"])
    out = heading(depth, num, title)
    out.append("")
    out.extend(convert_body(sec["body"]))
    for sub in sec["subs"]:
        snum, stitle = split_num(sub["raw"])
        out.append("")
        out.extend(heading(depth + 1, snum, stitle))
        out.append("")
        out.extend(convert_body(sub["body"]))
    return out


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    if not os.path.isfile(src):
        print(">> ERROR: %s が見つかりません。" % src, file=sys.stderr)
        return 1
    print(">> Converting Markdown to AsciiDoc: %s" % src)
    doc = parse(src)
    index = [
        "= Google Generative AI Leader 認定試験対策資料",
        "吉田敏幸 <yostos@yostos.org>",
        ":description: Google Cloud Generative AI Leader 認定試験の対策ノート。"
        "生成AIの基礎、Google Cloud の製品群、出力の改善技法、ビジネス戦略と責任あるAI を、"
        "要件から製品・技法を引ける形にまとめる。",
        "include::_attributes.adoc[]",
        ":revnumber: 0.1.0",
        ":revdate: 2026-08-27",
        ":version-label: Revision",
        "",
    ]
    lead = [l for l in doc["lead"] if l.strip()]
    if lead:
        index.extend(convert_body(lead))
        index.append("")

    for ch in doc["chapters"]:
        num, title = split_num(ch["raw"])

        if num.startswith("付録"):
            base, _ = APPENDICES[num[-1]]
            body = ["= " + title, "include::../_attributes.adoc[]", ""]
            body.extend(convert_body(ch["lead"]))
            for sec in ch["secs"]:
                body.append("")
                body.extend(emit_section(sec, 2))
            write("%s/appendix/%s.adoc" % (DST, base), body)
            index.append("[appendix]")
            index.append("include::appendix/%s.adoc[leveloffset=+1]" % base)
            index.append("")
            continue

        dirname, chtitle = CHAPTERS[num]
        chfile = ["= " + chtitle, "include::../_attributes.adoc[]", ""]
        chfile.extend(convert_body(ch["lead"]))
        if ch["lead"] and any(l.strip() for l in ch["lead"]):
            chfile.append("")

        if num == "0":
            # 前付けは短いので 1 ファイルにまとめる。
            for sec in ch["secs"]:
                chfile.extend(emit_section(sec, 2))
                chfile.append("")
            index.append("[preface]")
        else:
            for sec in ch["secs"]:
                snum, _ = split_num(sec["raw"])
                base = SECTION_FILES[snum]
                secfile = emit_section(sec, 1)
                pos = 2 if secfile[0].startswith("[#") else 1
                secfile.insert(pos, "include::../_attributes.adoc[]")
                write("%s/%s/%s.adoc" % (DST, dirname, base), secfile)
                chfile.append("include::%s.adoc[leveloffset=+1]" % base)
                chfile.append("")

        write("%s/%s/index.adoc" % (DST, dirname), chfile)
        index.append("include::%s/index.adoc[leveloffset=+1]" % dirname)
        index.append("")

    write("%s/index.adoc" % DST, index)


if __name__ == "__main__":
    sys.exit(main())
