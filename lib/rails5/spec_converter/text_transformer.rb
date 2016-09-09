require 'parser/current'
require 'astrolabe/builder'
require 'rails5/spec_converter/text_transformer_options'

module Rails5
  module SpecConverter
    HTTP_VERBS = %i(get post put patch delete)
    # technically format is special
    ALLOWED_KWARG_KEYS = %i(params session flash method body xhr format)

    class TextTransformer
      def initialize(content, options = TextTransformerOptions.new)
        @options = options
        @content = content

        @source_buffer = Parser::Source::Buffer.new('(string)')
        @source_buffer.source = @content

        ast_builder = Astrolabe::Builder.new
        @parser = Parser::CurrentRuby.new(ast_builder)

        @source_rewriter = Parser::Source::Rewriter.new(@source_buffer)
      end

      def transform
        root_node = @parser.parse(@source_buffer)
        root_node.each_node(:send) do |node|
          target, verb, action, *args = node.children
          next unless args.length > 0
          next unless target.nil? && HTTP_VERBS.include?(verb)

          if args[0].hash_type?
            if args[0].children.length == 0
              wrap_arg(args[0], 'params')
            elsif has_kwsplat?(args[0])
              warn_about_ambiguous_params(node) if @options.warn_about_ambiguous_params?
              next
            else
              next if looks_like_route_definition?(args[0])
              next if has_key?(args[0], :params)

              write_params_hash(
                hash_node: args[0],
                original_indent: node.loc.expression.source_line.match(/^(\s*)/)[1]
              )
            end
          else
            warn_about_ambiguous_params(node) if @options.warn_about_ambiguous_params?
            wrap_arg(args[0], 'params') if @options.wrap_ambiguous_params?
          end

          wrap_arg(args[1], 'headers') if args[1]
        end

        @source_rewriter.process
      end

      private

      def looks_like_route_definition?(hash_node)
        keys = hash_node.children.map { |pair| pair.children[0].children[0] }
        route_definition_keys = [:to, :controller]
        return true if route_definition_keys.all? { |k| keys.include?(k) }

        hash_node.children.each do |pair|
          key = pair.children[0].children[0]
          if key == :to
            if pair.children[1].str_type?
              value = pair.children[1].children[0]
              return true if value.match(/^\w+#\w+$/)
            end
          end
        end

        false
      end

      def has_kwsplat?(hash_node)
        hash_node.children.any? { |node| node.kwsplat_type? }
      end

      def has_key?(hash_node, key)
        hash_node.children.any? { |pair| pair.children[0].children[0] == key }
      end

      def write_params_hash(hash_node:, original_indent: )
        pairs_that_belong_in_params, pairs_that_belong_outside_params = partition_params(hash_node)

        if pairs_that_belong_in_params.length > 0
          joiner = joiner_between_pairs(hash_node)
          params_hash = appropriately_spaced_params_hash(
            hash_node: hash_node,
            pairs: pairs_that_belong_in_params,
            original_indent: original_indent
          )

          rewritten_hashes = ["params: #{params_hash}"]
          if pairs_that_belong_outside_params.length > 0
            rewritten_hashes << restring_hash(pairs_that_belong_outside_params, joiner: joiner)
          end
          @source_rewriter.replace(
            hash_node.loc.expression,
            rewritten_hashes.join(joiner)
          )
        end
      end

      def partition_params(hash_node)
        pairs_that_belong_in_params = []
        pairs_that_belong_outside_params = []

        hash_node.children.each do |pair|
          key = pair.children[0].children[0]

          if ALLOWED_KWARG_KEYS.include?(key)
            pairs_that_belong_outside_params << pair
          else
            pairs_that_belong_in_params << pair
          end
        end
        return pairs_that_belong_in_params, pairs_that_belong_outside_params
      end

      def indent_before_first_pair(hash_node)
        return nil unless hash_node.children.length > 0

        text_before_first_pair = @content[hash_node.loc.expression.begin_pos...hash_node.children.first.loc.expression.begin_pos]
        extract_indent(text_before_first_pair)
      end

      def indent_after_last_pair(hash_node)
        return nil unless hash_node.children.length > 0

        text_after_last_pair = @content[hash_node.children.last.loc.expression.end_pos...hash_node.loc.expression.end_pos]
        extract_indent(text_after_last_pair)
      end

      def indent_of_first_value_if_multiline(hash_node, original_indent)
        return nil if hash_node.children.length == 0
        first_value = hash_node.children[0].children[1]
        return nil unless first_value.hash_type? || first_value.array_type?
        value_str_lines = node_to_string(first_value).split("\n")
        return nil if value_str_lines.length == 1
        return nil unless value_str_lines[0].match(/[\s\[{]/)

        value_str_lines[1].match(/^(\s*)/)[1].sub(original_indent, '')
      end

      def additional_indent(hash_node)
        return nil if indent_before_first_pair(hash_node)

        joiner = joiner_between_pairs(hash_node)
        joiner && joiner.include?("\n") ? @options.indent : nil
      end

      def existing_indent(hash_node)
        text_before_hash = text_before_node(hash_node)
        whitespace_indent = extract_indent(text_before_hash)
        return whitespace_indent if whitespace_indent

        return indent_before_first_pair(hash_node) if indent_before_first_pair(hash_node)

        joiner = joiner_between_pairs(hash_node)
        extract_indent(joiner) || ''
      end

      def no_space_after_curly?(hash_node)
        hash_node.parent.loc.expression.source.match(/{\S/)
      end

      def joiner_between_pairs(hash_node)
        texts_between = []
        hash_node.children[0..-2].each_with_index do |pair, index|
          next_pair = hash_node.children[index + 1]
          texts_between << text_between_siblings(pair, next_pair)
        end
        if texts_between.uniq.length > 1
          log "Inconsistent whitespace between hash pairs, using the first separator (#{texts_between[0].inspect})."
          log "Seen when processing this expression: \n```\n#{hash_node.loc.expression.source}\n```\n\n"
        end
        texts_between[0]
      end

      def text_between_siblings(node1, node2)
        @content[node1.loc.expression.end_pos...node2.loc.expression.begin_pos]
      end

      def appropriately_spaced_params_hash(hash_node:, pairs:, original_indent: )
        outer_indent = existing_indent(hash_node)
        middle_indent = indent_of_first_value_if_multiline(hash_node, original_indent)
        inner_indent = additional_indent(hash_node)

        if inner_indent || middle_indent || indent_before_first_pair(hash_node)
          restrung_hash = restring_hash(
            pairs,
            indent: outer_indent + (inner_indent || ''),
            joiner: ",\n"
          )
          if middle_indent
            restrung_hash = original_indent + add_indent(restrung_hash, middle_indent)
          end
          final_brace_indent = if middle_indent
                                 original_indent
                               else
                                 indent_after_last_pair(hash_node) || outer_indent
                               end
          "{\n#{restrung_hash}\n#{final_brace_indent}}"
        else
          curly_sep = determine_curly_sep(hash_node)
          "{#{curly_sep}#{restring_hash(pairs)}#{curly_sep}}"
        end
      end

      def determine_curly_sep(hash_node)
        return ' ' if @options.hash_spacing == true
        return '' if @options.hash_spacing == false

        no_space_after_curly?(hash_node) ? '' : ' '
      end

      def wrap_arg(node, key)
        node_loc = node.loc.expression
        node_source = node_loc.source
        if node.hash_type? && !node_source.match(/^\s*\{.*\}$/m)
          node_source = "{ #{node_source} }"
        end
        @source_rewriter.replace(node_loc, "#{key}: #{node_source}")
      end

      def restring_hash(pairs, joiner: ", ", indent: '')
        pairs.map { |pair| "#{indent}#{pair.loc.expression.source}" }.join(joiner)
      end

      def add_indent(str, indent)
        str.split("\n").map { |line| indent + line }.join("\n")
      end

      def extract_indent(str)
        return unless str

        match = str.match("\n(\s*)")
        match[1] if match
      end

      def text_before_node(node)
        previous_sibling = node.parent.children[node.sibling_index - 1]
        return nil unless previous_sibling.loc.expression

        text_between_siblings(previous_sibling, node)
      end

      def node_to_string(node)
        @content[node.loc.expression.begin_pos...node.loc.expression.end_pos]
      end

      def warn_about_ambiguous_params(node)
        log "Ambiguous params found"
        log "#{@options.file_path}:#{node.loc.line}" if @options.file_path
        log "```\n#{node.loc.expression.source}\n```\n\n"
      end

      def log(str)
        return if @options.quiet?

        puts str
      end
    end
  end
end
