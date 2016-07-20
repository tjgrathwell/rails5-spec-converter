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

  it 'assigns additional arguments as "headers"' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, {search: 'bayleef'}, {'X-PANCAKE' => 'banana'}
      end
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: {search: 'bayleef'}, headers: {'X-PANCAKE' => 'banana'}
      end
    EOT
  end

  it 'wraps header args in curly braces if they are not already present' do
    result = described_class.new(<<-EOT.strip_heredoc).transform
      get :show, nil, 'X-BANANA' => 'pancake'
    EOT

    expect(result).to eq(<<-EOT.strip_heredoc)
      get :show, params: nil, headers: { 'X-BANANA' => 'pancake' }
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

  describe 'things that look like route definitions' do
    it 'leaves invocations that look like route definitions undisturbed' do
      test_content_stringy = <<-EOT
        get 'profile', to: 'users#show'
      EOT
      expect(described_class.new(test_content_stringy).transform).to eq(test_content_stringy)

      test_content_hashy = <<-EOT
        get 'profile', to: :show, controller: 'users'
      EOT
      expect(described_class.new(test_content_hashy).transform).to eq(test_content_hashy)
    end

    it 'adds "params" to invocations that have the key `to` but are not route definitions' do
      result = described_class.new(<<-EOT.strip_heredoc).transform
        get 'users', from: yesterday, to: today
      EOT

      expect(result).to eq(<<-EOT.strip_heredoc)
        get 'users', params: { from: yesterday, to: today }
      EOT
    end
  end
end