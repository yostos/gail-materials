# 全ての表に unbreakable オプションを付与し、ページ跨ぎの分断を防ぐ。
#
# asciidoctor-pdf は unbreakable な表が現在のページに収まらない場合は次ページへ送り、
# 1 ページに収まらない表は分割可能として扱う（＝大きすぎる表は従来どおり分割される）。
# 表のキャプションも表と同じコンテナに包まれるため、キャプションだけが前ページに
# 取り残されることも防げる。
#
# 特定の表だけ従来どおり分割したい場合は、その表に [%breakable] を指定する。

require 'asciidoctor/extensions'

Asciidoctor::Extensions.register do
  tree_processor do
    process do |document|
      (document.find_by context: :table).each do |table|
        table.set_option 'unbreakable' unless table.option? 'breakable'
      end
      nil
    end
  end
end
