class TextTransformerOptions
  attr_accessor :strategy, :hash_spacing, :indent, :file_path
  attr_writer :quiet, :warn_if_ambiguous

  def initialize
    @file_path = nil
    @strategy = :optimistic
    @quiet = false
    @indent = '  '
    @hash_spacing = nil
    @warn_if_ambiguous = false
  end

  def wrap_ambiguous_params?
    @strategy == :optimistic
  end

  def warn_about_ambiguous_params?
    @warn_if_ambiguous
  end

  def quiet?
    @quiet
  end
end