.DEFAULT_GOAL := help
.PHONY: help all pdf html chapters check clean fonts

# docs/*/index.adoc から章名(c0, c1, ...)を自動で拾う。
CHAPTERS := $(notdir $(patsubst %/,%,$(dir $(wildcard docs/*/index.adoc))))

all: pdf html ## 全体のPDFとHTMLを両方生成する。

fonts: ## PDFに埋め込む BIZ UDGothic を build/fonts に取得する。
	@./scripts/fetch-fonts.sh

pdf: fonts ## 全体のPDFを生成する。
	@./scripts/build-pdf.sh

html: ## 全体のHTMLを生成する。
	@./scripts/build-html.sh

pdf-%: fonts ## 章単体のPDFを生成する。例: make pdf-c3
	@./scripts/build-pdf.sh $*

html-%: ## 章単体のHTMLを生成する。例: make html-c3
	@./scripts/build-html.sh $*

chapters: fonts ## 全章を個別のPDF/HTMLに生成する。
	@for d in $(CHAPTERS); do \
		./scripts/build-pdf.sh $$d; \
		./scripts/build-html.sh $$d; \
	done

check: ## 壊れたinclude・相互参照などの警告を検出する。出力は破棄。
	@asciidoctor -r asciidoctor-diagram --failure-level=WARN -o /dev/null docs/index.adoc \
		&& echo ">> No warnings."

clean: ## 生成したPDF/HTMLを削除する。
	@rm -rf build/pdf build/html
	@echo ">> Cleanup done."

help: ## ヘルプを出力する。
	@grep -E '^[a-zA-Z_%-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| perl -pe 's{^([a-zA-Z_%-]+):.*?(##)}{$$1 $$2}' \
		| awk -F " *?## *?" '{printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
