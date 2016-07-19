require 'rails5/spec_converter/text_transformer'

module Rails5
  module SpecConverter
    class CLI
      def run
        Dir.glob("spec/**/*_spec.rb") do |path|
          original_content = File.read(path)
          transformed_content = Rails5::SpecConverter::TextTransformer.new(original_content).transform
          File.write(path, transformed_content)
        end
      end
    end
  end
end
