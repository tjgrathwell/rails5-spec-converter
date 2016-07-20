require 'spec_helper'

describe Rails5::SpecConverter::TextTransformer do
  it 'leaves invocations with no arguments undisturbed' do
    test_content = <<-EOT
      it 'executes the controller action' do
        get :index
      end
    EOT
    expect(described_class.new(test_content).transform).to eq(test_content)
  end

  it 'leaves invocations with only permitted keys undisturbed' do
    test_content = <<-EOT
      it 'executes the controller action' do
        get :index, format: :json
      end
    EOT
    expect(described_class.new(test_content).transform).to eq(test_content)
  end

  it 'can add "params: {}" if an empty hash of arguments is present' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, {}
      end
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: {}
      end
    EOT
  end

  it 'can add "params: {}" if the first argument is a method call' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, my_params
      end
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: my_params
      end
    EOT
  end

  it 'can add "params: {}" when only unpermitted keys are present' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, search: 'bayleef'
      end
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: { search: 'bayleef' }
      end
    EOT
  end

  it 'can add "params: {}" when both permitted and unpermitted keys are present' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, search: 'bayleef', format: :json
      end
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: { search: 'bayleef' }, format: :json
      end
    EOT
  end

  it 'keeps hashes tightly packed if the existing source has any tightly-packed hashes in it' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, {search: 'bayleef', format: :json}
      end
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: {search: 'bayleef'}, format: :json
      end
    EOT
  end
end