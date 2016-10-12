require 'spec_helper'

describe Rails5::SpecConverter::TestTypeIdentifier do
  describe 'determining the type of a test file' do
    def build_rspec_content(type = nil)
      <<-EOT.strip_heredoc
        describe "my test"#{type ? ", type: :#{type}" : nil} do
          it 'runs this test' do
            get :index
            expect(response).to be_success
          end
        end
      EOT
    end

    def build_minitest_content(type = nil)
      base_class = type == 'request' ? 'ActionDispatch::IntegrationTest' : 'ActionController::TestCase'
      <<-EOT.strip_heredoc
        class MyTest < #{base_class}
          def test_index
            get :index
            assert_match(/cool_content/, @response.body)
          end
        end
      EOT
    end

    it 'defaults to "request" for an unidentifiable file' do
      content = build_rspec_content
      identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
      expect(identifier.test_type).to eq(:request)
    end

    describe 'minitest' do
      {controller: %w(controllers), request: %w(requests integration api)}.each do |test_type, folders|
        folders.each do |folder_name|
          it "identifies files as \"#{test_type}\" if they live in the \"#{folder_name}\" folder" do
            content = build_rspec_content
            options = TextTransformerOptions.new
            options.file_path = "project/test/#{folder_name}/sample_test.rb"

            identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content, options)
            expect(identifier.test_type).to eq(test_type)
          end
        end
      end

      it 'identifies files as "controller" if they have a controllery subclass' do
        content = build_minitest_content('controller')
        identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
        expect(identifier.test_type).to eq(:controller)
      end

      it 'identifies files as "request" if they have a requesty subclass' do
        content = build_minitest_content('request')
        identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
        expect(identifier.test_type).to eq(:request)
      end
    end

    describe 'rspec' do
      {controller: %w(controllers), request: %w(requests integration api)}.each do |test_type, folders|
        folders.each do |folder_name|
          it "identifies files as \"#{test_type}\" if they live in the \"#{folder_name}\" folder" do
            content = build_rspec_content
            options = TextTransformerOptions.new
            options.file_path = "project/spec/#{folder_name}/sample_spec.rb"

            identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content, options)
            expect(identifier.test_type).to eq(test_type)
          end
        end
      end

      it 'identifies files as "controller" if they have controller metadata' do
        content = build_rspec_content('controller')
        identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
        expect(identifier.test_type).to eq(:controller)
      end

      it 'identifies files as "request" if they have request metadata' do
        content = build_rspec_content('request')
        identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
        expect(identifier.test_type).to eq(:request)
      end

      it 'prefers request metadata to folder location when determining file type' do
        content = build_rspec_content('request')
        options = TextTransformerOptions.new
        options.file_path = "project/spec/controllers/sample_spec.rb"

        identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content, options)
        expect(identifier.test_type).to eq(:request)
      end
    end
  end
end