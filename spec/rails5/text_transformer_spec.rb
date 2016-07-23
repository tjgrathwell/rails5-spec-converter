require 'spec_helper'

describe Rails5::SpecConverter::TextTransformer do
  it 'leaves invocations with no arguments undisturbed' do
    test_content = <<-RUBY
      get :index
    RUBY
    expect(described_class.new(test_content).transform).to eq(test_content)
  end

  it 'leaves invocations with only permitted keys undisturbed' do
    test_content = <<-RUBY
      get :index, format: :json
    RUBY
    expect(described_class.new(test_content).transform).to eq(test_content)
  end

  it 'leaves invocations that already have a "params" key undisturbed' do
    test_content = <<-RUBY
      post :create, params: {token: build.token}, headers: {'X-PANCAKE' => 'banana'}
    RUBY
    expect(described_class.new(test_content).transform).to eq(test_content)
  end

  it 'can add "params: {}" if an empty hash of arguments is present' do
    result = described_class.new(<<-RUBY.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, {}
      end
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: {}
      end
    RUBY
  end

  it 'can add "params: {}" if the first argument is a method call' do
    result = described_class.new(<<-RUBY.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, my_params
      end
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: my_params
      end
    RUBY
  end

  it 'can add "params: {}" when only unpermitted keys are present' do
    result = described_class.new(<<-RUBY.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, search: 'bayleef'
      end
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: { search: 'bayleef' }
      end
    RUBY
  end

  it 'can add "params: {}" when both permitted and unpermitted keys are present' do
    result = described_class.new(<<-RUBY.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, search: 'bayleef', format: :json
      end
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: { search: 'bayleef' }, format: :json
      end
    RUBY
  end

  describe 'header params' do
    it 'assigns additional arguments as "headers"' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        get :index, {search: 'bayleef'}, {'X-PANCAKE' => 'banana'}
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        get :index, params: {search: 'bayleef'}, headers: {'X-PANCAKE' => 'banana'}
      RUBY
    end

    it 'adds "params" and "header" keys regardless of surrounding whitespace' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        get :index, {
          search: 'bayleef'
        }, {
          'X-PANCAKE' => 'banana'
        }
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        get :index, params: {
          search: 'bayleef'
        }, headers: {
          'X-PANCAKE' => 'banana'
        }
      RUBY
    end

    it 'wraps header args in curly braces if they are not already present' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        get :show, nil, 'X-BANANA' => 'pancake'
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        get :show, params: nil, headers: { 'X-BANANA' => 'pancake' }
      RUBY
    end
  end

  it 'keeps hashes tightly packed if the existing source has any tightly-packed hashes in it' do
    result = described_class.new(<<-RUBY.strip_heredoc).transform
      it 'executes the controller action' do
        get :index, {search: 'bayleef', format: :json}
      end
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      it 'executes the controller action' do
        get :index, params: {search: 'bayleef'}, format: :json
      end
    RUBY
  end

  describe 'preserving whitespace' do
    it 'preserves hash indentation if the hash starts on a new line' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        it 'executes the controller action' do
          post :create, {
            color: 'blue',
            style: 'striped'
          }
        end
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        it 'executes the controller action' do
          post :create, params: {
            color: 'blue',
            style: 'striped'
          }
        end
      RUBY
    end

    it 'preserves hash indentation if the hash starts on a new line and a headers hash is present' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        post :create, {
          color: 'blue',
          size: {
            width: 10
          }
        }, {
          'header' => 'value'
        }
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        post :create, params: {
          color: 'blue',
          size: {
            width: 10
          }
        }, headers: {
          'header' => 'value'
        }
      RUBY
    end

    it 'indents hashes appropriately if they start on the same line as the action' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        post :show, branch_name: 'new_design3',
                    ref: 'foo',
                    format: :json
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        post :show, params: {
                      branch_name: 'new_design3',
                      ref: 'foo'
                    },
                    format: :json
      RUBY
    end

    it 'indents hashes appropriately if they start on a new line' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        post :show,
             branch_name: 'new_design3',
             ref: 'foo',
             format: :json
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        post :show,
             params: {
               branch_name: 'new_design3',
               ref: 'foo'
             },
             format: :json
      RUBY
    end
  end

  describe 'things that look like route definitions' do
    it 'leaves invocations that look like route definitions undisturbed' do
      test_content_stringy = <<-RUBY
        get 'profile', to: 'users#show'
      RUBY
      expect(described_class.new(test_content_stringy).transform).to eq(test_content_stringy)

      test_content_hashy = <<-RUBY
        get 'profile', to: :show, controller: 'users'
      RUBY
      expect(described_class.new(test_content_hashy).transform).to eq(test_content_hashy)
    end

    it 'adds "params" to invocations that have the key `to` but are not route definitions' do
      result = described_class.new(<<-RUBY.strip_heredoc).transform
        get 'users', from: yesterday, to: today
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        get 'users', params: { from: yesterday, to: today }
      RUBY
    end
  end
end