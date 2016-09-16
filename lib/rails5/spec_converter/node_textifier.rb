class NodeTextifier
  def initialize(content)
    @content = content
  end

  def text_before_first_pair(hash_node)
    @content[hash_node.loc.expression.begin_pos...hash_node.children.first.loc.expression.begin_pos]
  end

  def text_after_last_pair(hash_node)
    @content[hash_node.children.last.loc.expression.end_pos...hash_node.loc.expression.end_pos]
  end

  def text_before_node(node)
    previous_sibling = node.parent.children[node.sibling_index - 1]
    return nil unless previous_sibling.loc.expression

    text_between_siblings(previous_sibling, node)
  end

  def text_between_siblings(node1, node2)
    @content[node1.loc.expression.end_pos...node2.loc.expression.begin_pos]
  end

  def node_to_string(node)
    @content[node.loc.expression.begin_pos...node.loc.expression.end_pos]
  end
end