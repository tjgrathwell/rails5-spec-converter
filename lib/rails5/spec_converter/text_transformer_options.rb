class TextTransformerOptions
  attr_accessor :hash_spacing, :indent, :file_path
  attr_writer :quiet

  def initialize
    @file_path = nil
    @quiet = false
    @indent = '  '
    @hash_spacing = nil
  end

  def quiet?
    @quiet
  end
end