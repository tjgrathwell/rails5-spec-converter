require 'spec_helper'

describe Rails5::SpecConverter::TextTransformer do
  let(:controller_spec_file_path) { 'spec/controllers/test_spec.rb' }
  let(:request_spec_file_path) { 'spec/requests/test_spec.rb' }

  def transform(text, options = nil)
    if options
      described_class.new(text, options).transform
    else
      described_class.new(text).transform
    end
  end

  def quiet_transform(text)
    options = TextTransformerOptions.new
    options.quiet = true
    transform(text, options)
  end

  describe 'unparsable ruby' do
    let(:unparsable_content) do
      <<-RUBYISH
        gibberish do
      RUBYISH
    end

    it 'leaves unparsable ruby alone' do
      expect(quiet_transform(unparsable_content)).to eq(unparsable_content)
    end

    it 'prints a warning message' do
      expect {
        transform(unparsable_content)
      }.to output(/unparsable/i).to_stdout
    end
  end

  it 'leaves invocations with no arguments undisturbed' do
    test_content = <<-RUBY
      get :index
    RUBY
    expect(transform(test_content)).to eq(test_content)
  end

  it 'leaves invocations with only permitted keys undisturbed' do
    test_content = <<-RUBY
      get :index, format: :json
    RUBY
    expect(transform(test_content)).to eq(test_content)
  end

  it 'leaves invocations that already have a "params" key undisturbed' do
    test_content = <<-RUBY
      post :create, params: {token: build.token}, headers: {'X-PANCAKE' => 'banana'}
    RUBY
    expect(transform(test_content)).to eq(test_content)
  end

  it 'can add "params: {}" if an empty hash of arguments is present' do
    result = transform(<<-RUBY.strip_heredoc)
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

  it 'can add "params: {}" around hashes that contain a double-splat' do
    result = transform(<<-RUBY.strip_heredoc)
      get :index, **index_params, order: 'asc', format: :json
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      get :index, params: { **index_params, order: 'asc' }, format: :json
    RUBY
  end

  it 'can add "params: {}" around multiline hashes that contain a double-splat' do
    result = transform(<<-RUBY.strip_heredoc)
      let(:retrieve_index) do
        get :index, order: 'asc',
                    **index_params,
                    format: :json
      end
    RUBY

    expect(result).to eq(<<-RUBY.strip_heredoc)
      let(:retrieve_index) do
        get :index, params: {
                      order: 'asc',
                      **index_params
                    },
                    format: :json
      end
    RUBY
  end

  it 'can add "params: {}" when only unpermitted keys are present' do
    result = transform(<<-RUBY.strip_heredoc)
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
    result = transform(<<-RUBY.strip_heredoc)
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

  describe 'controller tests' do
    let(:controllery_file_options) do
      TextTransformerOptions.new.tap do |options|
        options.file_path = controller_spec_file_path
      end
    end

    describe 'session and flash params' do
      it 'assigns additional positional arguments as "session" and "flash"' do
        result = transform(<<-RUBY.strip_heredoc, controllery_file_options)
          get :index, {search: 'bayleef'}, {'session_property' => 'banana'}, {info: 'Great Search!'}
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          get :index, params: {search: 'bayleef'}, session: {'session_property' => 'banana'}, flash: {info: 'Great Search!'}
        RUBY
      end
    end
  end

  describe 'request tests' do
    let(:requesty_file_options) do
      TextTransformerOptions.new.tap do |options|
        options.file_path = request_spec_file_path
      end
    end

    describe 'header params' do
      it 'assigns additional arguments as "headers"' do
        result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
          get :index, {search: 'bayleef'}, {'X-PANCAKE' => 'banana'}
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          get :index, params: {search: 'bayleef'}, headers: {'X-PANCAKE' => 'banana'}
        RUBY
      end

      it 'adds "params" and "header" keys regardless of surrounding whitespace' do
        result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
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
        result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
          get :show, nil, 'X-BANANA' => 'pancake'
        RUBY

        expect(result).to eq(<<-RUBY.strip_heredoc)
          get :show, headers: { 'X-BANANA' => 'pancake' }
        RUBY
      end
    end
  end

  it 'keeps hashes tightly packed if the existing source has any tightly-packed hashes in it' do
    result = transform(<<-RUBY.strip_heredoc)
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
      result = transform(<<-RUBY.strip_heredoc)
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

    describe 'request tests' do
      let(:requesty_file_options) do
        TextTransformerOptions.new.tap do |options|
          options.file_path = request_spec_file_path
        end
      end

      it 'preserves hash indentation if the hash starts on a new line and a headers hash is present' do
        result = transform(<<-RUBY.strip_heredoc, requesty_file_options)
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
    end

    it 'indents hashes appropriately if they start on the same line as the action' do
      result = transform(<<-RUBY.strip_heredoc)
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
      result = transform(<<-RUBY.strip_heredoc)
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

    it 'indents hashes appropriately if they start on a new line and contain indented content' do
      result = transform(<<-RUBY.strip_heredoc)
        put :update,
          id: @rubygem.to_param,
          linkset: {
            code: @url
          },
          format: :json
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        put :update,
          params: {
            id: @rubygem.to_param,
            linkset: {
              code: @url
            }
          },
          format: :json
      RUBY
    end

    describe 'inconsistent hash spacing' do
      describe 'when a hash has inconsistent indentation' do
        it 'rewrites hashes as single-line if the first two pairs are on the same line' do
          result = quiet_transform(<<-RUBY.strip_heredoc)
            let(:perform_action) do
              post :search,
                type: 'fire', limit: 10,
                order: 'asc'
            end
          RUBY

          expect(result).to eq(<<-RUBY.strip_heredoc)
            let(:perform_action) do
              post :search,
                params: { type: 'fire', limit: 10, order: 'asc' }
            end
          RUBY
        end
      end
    end

    it 'indents hashes appropriately if they start on the first line but contain indented content' do
      result = transform(<<-RUBY.strip_heredoc)
        describe 'important stuff' do
          let(:perform_action) do
            post :mandrill, mandrill_events: [{
              "event" => "hard_bounce"
            }]
          end
        end
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        describe 'important stuff' do
          let(:perform_action) do
            post :mandrill, params: {
              mandrill_events: [{
                "event" => "hard_bounce"
              }]
            }
          end
        end
      RUBY
    end
  end

  describe 'trailing commas' do
    it 'preserves trailing commas if they exist in any of the transformed hashes' do
      result = transform(<<-RUBY.strip_heredoc)
        let(:perform_request) do
          post :show, {
            branch_name: 'new_design3',
            ref: 'foo',
            format: :json,
          }
        end
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        let(:perform_request) do
          post :show, {
            params: {
              branch_name: 'new_design3',
              ref: 'foo',
            },
            format: :json,
          }
        end
      RUBY
    end

    it 'adds a comma between the params hash and the format key' do
      result = transform(<<-RUBY.strip_heredoc)
        let(:perform_request) do
          post :show, {
            branch_name: 'new_design3',
            ref: 'foo',
            format: :json
          }
        end
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        let(:perform_request) do
          post :show, {
            params: {
              branch_name: 'new_design3',
              ref: 'foo'
            },
            format: :json
          }
        end
      RUBY
    end
  end

  describe 'things that look like route definitions' do
    it 'leaves invocations that look like route definitions undisturbed' do
      test_content_stringy = <<-RUBY
        get 'profile', to: 'users#show'
      RUBY
      expect(transform(test_content_stringy)).to eq(test_content_stringy)

      test_content_hashy = <<-RUBY
        get 'profile', to: :show, controller: 'users'
      RUBY
      expect(transform(test_content_hashy)).to eq(test_content_hashy)
    end

    it 'adds "params" to invocations that have the key `to` but are not route definitions' do
      result = transform(<<-RUBY.strip_heredoc)
        get 'users', from: yesterday, to: today
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        get 'users', params: { from: yesterday, to: today }
      RUBY
    end
  end

  describe 'optional configuration' do
    it 'allows a custom indent to be set' do
      options = TextTransformerOptions.new
      options.indent = '    '

      result = transform(<<-RUBY.strip_heredoc, options)
        post :show, branch_name: 'new_design3',
                    ref: 'foo'
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        post :show, params: {
                        branch_name: 'new_design3',
                        ref: 'foo'
                    }
      RUBY
    end

    it 'allows extra spaces whitespace in hashes to be forced off' do
      options = TextTransformerOptions.new
      options.hash_spacing = false

      result = transform(<<-RUBY.strip_heredoc, options)
        get :index, search: 'bayleef', format: :json
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        get :index, params: {search: 'bayleef'}, format: :json
      RUBY
    end

    it 'allows extra spaces whitespace in hashes to be forced on' do
      options = TextTransformerOptions.new
      options.hash_spacing = true

      result = transform(<<-RUBY.strip_heredoc, options)
        post :users, user: {name: 'bayleef'}
      RUBY

      expect(result).to eq(<<-RUBY.strip_heredoc)
        post :users, params: { user: {name: 'bayleef'} }
      RUBY
    end

    describe 'warning about inconsistent indentation' do
      it 'produces warnings if hashes have inconsistent separators between pairs' do
        inconsistent_spacing_example = <<-RUBY
          post :users, name: 'SampleUser', email: 'sample@example.com',
                       role: Roles::User
        RUBY

        expect {
          transform(inconsistent_spacing_example)
        }.to output(/inconsistent/i).to_stdout
      end
    end
  end
end