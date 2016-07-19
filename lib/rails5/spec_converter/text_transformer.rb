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
          target, verb, action, first_argument = node.children
          if target.nil? && HTTP_VERBS.include?(verb)
            if first_argument && first_argument.hash_type?
              hash_node = first_argument

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
          end
        end

        source_rewriter.process
      end

      private

      def restring_hash(pairs)
        pairs.map { |pair| pair.loc.expression.source }.join(", ")
      end
    end
  end
end
