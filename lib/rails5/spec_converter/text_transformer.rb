require 'parser/current'
require 'astrolabe/builder'

module Rails5
  module SpecConverter
    HTTP_VERBS = %i(get post put patch delete)
    # technically format is special
    ALLOWED_KWARG_KEYS = %i(params session flash method body xhr format)

    class TextTransformer
      def initialize(content)
        @content = content
      end

      def transform
        source_buffer = Parser::Source::Buffer.new('(string)')
        source_buffer.source = @content

        ast_builder = Astrolabe::Builder.new
        parser = Parser::CurrentRuby.new(ast_builder)

        source_rewriter = Parser::Source::Rewriter.new(source_buffer)

        root_node = parser.parse(source_buffer)
        root_node.each_node(:send) do |node|
          target, verb, action, *args = node.children
          next unless args.length > 0
          next unless target.nil? && HTTP_VERBS.include?(verb)

          if args[0].hash_type? && args[0].children.length > 0
            next if looks_like_route_definition?(args[0])

            write_params_hash(source_rewriter, args[0])
          else
            wrap_arg(source_rewriter, args[0], 'params')
          end

          wrap_arg(source_rewriter, args[1], 'headers') if args[1]
        end

        source_rewriter.process
      end

      private

      def looks_like_route_definition?(hash_node)
        keys = hash_node.children.map { |pair| pair.children[0].children[0] }
        return true if (keys & [:to, :controller]) == keys

        hash_node.children.each do |pair|
          key = pair.children[0].children[0]
          value = pair.children[1].children[0]
          if key == :to
            return true if value.match(/^\w+#\w+$/)
          end
        end

        false
      end

      def write_params_hash(source_rewriter, hash_node)
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

        curly_sep = hash_node.parent.loc.expression.source.match(/{\S/) ? '' : ' '

        if pairs_that_belong_in_params.length > 0
          rewritten_hashes = ["params: {#{curly_sep}#{restring_hash(pairs_that_belong_in_params)}#{curly_sep}}"]
          if pairs_that_belong_outside_params.length > 0
            rewritten_hashes << restring_hash(pairs_that_belong_outside_params)
          end
          source_rewriter.replace(
            hash_node.loc.expression,
            rewritten_hashes.join(', ')
          )
        end
      end

      def wrap_arg(source_rewriter, node, key)
        node_loc = node.loc.expression
        node_source = node_loc.source
        if node.hash_type? && !node_source.match(/^\s*\{.*\}$/)
          node_source = "{ #{node_source} }"
        end
        source_rewriter.replace(node_loc, "#{key}: #{node_source}")
      end

      def restring_hash(pairs)
        pairs.map { |pair| pair.loc.expression.source }.join(", ")
      end
    end
  end
end
