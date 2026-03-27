# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Field::Rules do
  subject(:rules) { described_class.new(context:, scope_error_instance:) }

  let(:scope_error_instance) { RestmeRails::ScopeError.new }

  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      query_params: query_params
    )
  end

  let(:query_params) { {} }

  describe "#errors" do
    subject(:errors) { rules.errors }

    context "when all field selections are allowed" do
      let(:query_params) { { fields_select: "id,name" } }

      it { is_expected.to be_nil }
      it { expect { errors }.not_to change(scope_error_instance, :scope_errors) }
    end

    context "when fields_select contains a disallowed field" do
      let(:query_params) { { fields_select: "id,invalid_field" } }

      it { is_expected.to eq(true) }

      it "registers a bad_request error" do
        errors
        expect(scope_error_instance.scope_status).to eq(:bad_request)
      end

      it "includes the disallowed field in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(:invalid_field)
      end
    end

    context "when nested_fields_select contains a disallowed association" do
      let(:query_params) { { nested_fields_select: "unknown_assoc" } }

      it { is_expected.to eq(true) }

      it "includes the disallowed association in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(:unknown_assoc)
      end
    end

    context "when both fields_select and nested_fields_select have disallowed entries" do
      let(:query_params) { { fields_select: "bad_field", nested_fields_select: "bad_assoc" } }

      it "combines both into a single error entry" do
        errors
        expect(scope_error_instance.scope_errors.size).to eq(1)
        expect(scope_error_instance.scope_errors.first[:body]).to include(:bad_field, :bad_assoc)
      end
    end
  end
end
