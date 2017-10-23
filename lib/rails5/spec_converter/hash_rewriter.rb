require 'rails5/spec_converter/node_textifier'

class HashRewriter
  OUTSIDE_PARAMS_KEYS = %i(format)

  attr_reader :hash_node, :original_indent

  def initialize(content:, hash_node:, original_indent:, options:)
    @options = options
    @content = content
    @hash_node = hash_node
    @original_indent = original_indent
    @textifier = NodeTextifier.new(@content)
    partition_params(@hash_node)
  end

  def rewritten_params_hash
    return if @pairs_that_belong_in_params.length == 0

    rewritten_hashes = []

    warn_if_inconsistent_indentation

    if multiline? && should_wrap_rewritten_hash_in_curly_braces?
      params_hash = restring_hash(
        @pairs_that_belong_in_params,
        joiner: ",\n"
      )

      other_hash = restring_hash(
        @pairs_that_belong_outside_params,
        joiner: ",\n"
      )

      new_wrapped_hash_content = wrap_and_indent(
        "{",
        "}",
        [
          wrap_and_indent(
            "params: {",
            "},",
            params_hash,
            @options.indent
          ),
          "#{other_hash}"
        ].join("\n"),
        @options.indent
      )
      return add_indent(new_wrapped_hash_content, original_indent, skip_first_line: true)
    elsif multiline? && should_try_to_rewrite_multiline_hash?
      params_hash = appropriately_indented_params_hash(
        pairs: @pairs_that_belong_in_params
      )

      rewritten_hashes << "params: #{params_hash}"
    else
      curly_sep = determine_curly_sep(hash_node)
      rewritten_hashes << "params: {#{curly_sep}#{restring_hash(@pairs_that_belong_in_params)}#{curly_sep}}"
    end

    if has_keys_outside_params?
      rewritten_hashes << restring_hash(
        @pairs_that_belong_outside_params,
        joiner: first_joiner_between_pairs
      )
    end

    rewritten_hashes.join(first_joiner_between_pairs)
  end

  def should_rewrite_hash?
    @pairs_that_belong_in_params.length > 0
  end

  def has_keys_outside_params?
    @pairs_that_belong_outside_params.length > 0
  end

  def should_wrap_rewritten_hash_in_curly_braces?
    multiline? && has_keys_outside_params? && @textifier.node_to_string(hash_node) =~ /^{\n/
  end

  def should_try_to_rewrite_multiline_hash?
    return false unless multiline?
    return true unless first_joiner_between_pairs
    first_joiner_between_pairs =~ /\n/
  end

  private

  def partition_params(hash_node)
    @pairs_that_belong_in_params = []
    @pairs_that_belong_outside_params = []

    hash_node.children.each do |pair|
      key = pair.children[0].children[0]

      if OUTSIDE_PARAMS_KEYS.include?(key)
        @pairs_that_belong_outside_params << pair
      else
        @pairs_that_belong_in_params << pair
      end
    end
  end

  def has_trailing_comma?(hash_node)
    @textifier.text_after_last_pair(hash_node) =~ /,/
  end

  def indent_before_first_pair(hash_node)
    return nil unless hash_node.children.length > 0

    extract_indent(@textifier.text_before_first_pair(hash_node))
  end

  def indent_after_last_pair(hash_node)
    return nil unless hash_node.children.length > 0

    extract_indent(@textifier.text_after_last_pair(hash_node))
  end

  def multiline?
    @textifier.node_to_string(hash_node).include?("\n")
  end

  def indent_of_first_value_if_multiline(hash_node)
    return nil if hash_node.children.length == 0
    return nil unless hash_node.children[0].pair_type?

    first_value = hash_node.children[0].children[1]
    return nil unless first_value.hash_type? || first_value.array_type?
    value_str_lines = @textifier.node_to_string(first_value).split("\n")
    return nil if value_str_lines.length == 1
    return nil unless value_str_lines[0].match(/[\s\[{]/)

    value_str_lines[1].match(/^(\s*)/)[1].sub(original_indent, '')
  end

  def should_indent_restrung_content?(hash_node)
    return nil if indent_before_first_pair(hash_node)

    joiner = first_joiner_between_pairs
    joiner && joiner.include?("\n")
  end

  def existing_indent(hash_node)
    text_before_hash = @textifier.text_before_node(hash_node)
    whitespace_indent = extract_indent(text_before_hash)
    return whitespace_indent if whitespace_indent

    return indent_before_first_pair(hash_node) if indent_before_first_pair(hash_node)

    joiner = first_joiner_between_pairs
    extract_indent(joiner) || ''
  end

  def no_space_after_curly?(hash_node)
    hash_node.parent.loc.expression.source.match(/{\S/)
  end

  def texts_between_pairs
    return @texts_between if @texts_between

    @texts_between = []
    hash_node.children[0..-2].each_with_index do |pair, index|
      next_pair = hash_node.children[index + 1]
      @texts_between << @textifier.text_between_siblings(pair, next_pair)
    end
    @texts_between
  end

  def first_joiner_between_pairs
    texts_between_pairs[0]
  end

  def has_inconsistent_indentation?
    texts_between_pairs.uniq.length > 1
  end

  def warn_if_inconsistent_indentation
    return unless has_inconsistent_indentation?

    log "Inconsistent whitespace between hash pairs, using the first separator (#{texts_between_pairs[0].inspect})."
    log "Seen when processing this expression: \n```\n#{hash_node.loc.expression.source}\n```\n\n"
  end

  def appropriately_indented_params_hash(pairs:)
    outer_indent = existing_indent(hash_node)

    restrung_hash = restring_hash(
      pairs,
      indent: outer_indent,
      joiner: ",\n"
    )

    if should_indent_restrung_content?(hash_node)
      restrung_hash = add_indent(restrung_hash, @options.indent)
    end

    middle_indent = indent_of_first_value_if_multiline(hash_node)
    if middle_indent
      restrung_hash = original_indent + add_indent(restrung_hash, middle_indent)
    end
    final_brace_indent = if middle_indent
                           original_indent
                         else
                           indent_after_last_pair(hash_node) || outer_indent
                         end
    "{\n#{restrung_hash}\n#{final_brace_indent}}"
  end

  def determine_curly_sep(hash_node)
    return ' ' if @options.hash_spacing == true
    return '' if @options.hash_spacing == false

    no_space_after_curly?(hash_node) ? '' : ' '
  end

  def restring_hash(pairs, joiner: ", ", indent: '')
    hash_string = pairs.map { |pair| "#{indent}#{pair.loc.expression.source}" }.join(joiner)
    if has_trailing_comma?(hash_node)
      hash_string + ','
    else
      hash_string
    end
  end

  def add_indent_and_curly_braces(str, indent)
    "{\n#{add_indent(str, indent)}\n}"
  end

  def wrap_and_indent(start_string, end_string, inner_string, indent)
    "#{start_string}\n#{add_indent(inner_string, indent)}\n#{end_string}"
  end

  def add_indent(str, indent, skip_first_line: false)
    str.split("\n").each_with_index.map do |line, index|
      if index.zero? && skip_first_line
        line
      else
        indent + line
      end
    end.join("\n")
  end

  def extract_indent(str)
    return unless str

    match = str.match("\n(\s*)")
    match[1] if match
  end

  def log(str)
    return if @options.quiet?

    puts str
  end
end