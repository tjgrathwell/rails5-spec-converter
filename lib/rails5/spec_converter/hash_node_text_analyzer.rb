class HashNodeTextAnalyzer
  attr_reader :content, :hash_node

  def initialize(content, hash_node)
    @content = content
    @hash_node = hash_node
  end

  def text_before_first_pair
    content[hash_node.loc.expression.begin_pos...hash_node.children.first.loc.expression.begin_pos]
  end

  def text_after_last_pair
    content[hash_node.children.last.loc.expression.end_pos...hash_node.loc.expression.end_pos]
  end
end