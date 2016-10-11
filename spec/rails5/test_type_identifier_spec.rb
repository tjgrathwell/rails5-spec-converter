require 'spec_helper'

describe Rails5::SpecConverter::TestTypeIdentifier do
  describe 'determining the type of a test file' do
    def build_test_content(type = nil)
      <<-EOT.strip_heredoc
        describe "my test"#{type ? ", type: :#{type}" : nil} do
          it 'runs this test' do
            get :index
            expect(response).to be_success
          end
        end
      EOT
    end

    it 'defaults to "request" for an unidentifiable file' do
      content = build_test_content
      identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
      expect(identifier.test_type).to eq(:request)
    end

    it 'identifies files as "controller" if they live in the "controllers" folder' do
      content = build_test_content
      options = TextTransformerOptions.new
      options.file_path = "project/spec/controllers/sample_spec.rb"

      identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content, options)
      expect(identifier.test_type).to eq(:controller)
    end

    it 'prefers request metadata to folder location when determining file type' do
      content = build_test_content('request')
      options = TextTransformerOptions.new
      options.file_path = "project/spec/controllers/sample_spec.rb"

      identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content, options)
      expect(identifier.test_type).to eq(:request)
    end

    %w(requests integration api).each do |folder_name|
      it "identifies files as \"request\" if they live in the \"#{folder_name}\" folder" do
        content = build_test_content
        options = TextTransformerOptions.new
        options.file_path = "project/spec/#{folder_name}/sample_spec.rb"

        identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content, options)
        expect(identifier.test_type).to eq(:request)
      end
    end

    it 'identifies files as "controller" if they have controller metadata' do
      content = build_test_content('controller')
      identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
      expect(identifier.test_type).to eq(:controller)
    end

    it 'identifies files as "request" if they have request metadata' do
      content = build_test_content('request')
      identifier = Rails5::SpecConverter::TestTypeIdentifier.new(content)
      expect(identifier.test_type).to eq(:request)
    end
  end
end