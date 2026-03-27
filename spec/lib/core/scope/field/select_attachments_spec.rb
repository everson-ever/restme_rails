# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Field::SelectAttachments do
  subject(:select_attachments) do
    described_class.new(
      context:,
      scope_error_instance:,
      valid_nested_fields_select: valid_nested_fields_select
    )
  end

  let(:context) { instance_double(RestmeRails::Context, model_class: Product, query_params: query_params) }
  let(:valid_nested_fields_select) { nil }
  let(:scope_error_instance) { RestmeRails::ScopeError.new }
  let(:query_params) { {} }

  describe "#nested_include_options" do
    subject { select_attachments.send(:nested_include_options) }

    context "when valid_nested_fields_select is nil" do
      it { is_expected.to eq({}) }
    end

    context "when all associations have nil (no field restriction)" do
      let(:valid_nested_fields_select) { { establishment: nil, setting: nil } }

      it { is_expected.to eq({ establishment: {}, setting: {} }) }
    end

    context "when an association has specific fields selected" do
      let(:valid_nested_fields_select) { { establishment: %i[id name] } }

      it { is_expected.to eq({ establishment: { only: %i[id name] } }) }
    end

    context "when mixing nil and array values" do
      let(:valid_nested_fields_select) { { establishment: %i[id name], setting: nil } }

      it { is_expected.to eq({ establishment: { only: %i[id name] }, setting: {} }) }
    end
  end

  describe "#errors" do
    subject(:errors) { select_attachments.errors }

    context "when attachment_fields_select is blank" do
      it { is_expected.to be_nil }
      it { expect { errors }.not_to change(scope_error_instance, :scope_errors) }
    end

    context "when an attachment field does not exist in the model" do
      let(:query_params) { { attachment_fields_select: "file" } }

      it "registers a bad_request error" do
        errors
        expect(scope_error_instance.scope_status).to eq(:bad_request)
      end

      it "includes the unknown attachment field in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(:file)
      end
    end
  end
end
