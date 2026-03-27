# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Filter::Rules do
  subject(:rules) { described_class.new(context:, scope_error_instance:) }

  let(:scope_error_instance) { RestmeRails::ScopeError.new }
  let(:request) { instance_double(RequestMock, get?: true) }

  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      query_params: query_params,
      params: params,
      request: request
    )
  end

  let(:query_params) { {} }
  let(:params) { {} }

  describe "#process" do
    subject(:sql) { rules.process(Product.all).to_sql }

    context "when no filter params are present" do
      it { is_expected.not_to include("WHERE") }
    end

    context "when filtering by name_equal" do
      let(:query_params) { { name_equal: "Foo" } }

      it { is_expected.to include("products.name = 'Foo'") }
    end

    context "when filtering by name_like" do
      let(:query_params) { { name_like: "oo" } }

      it { is_expected.to include("ILIKE '%oo%'") }
    end

    context "when filtering by establishment_id_equal" do
      let(:query_params) { { establishment_id_equal: "10" } }

      it { is_expected.to include("products.establishment_id = '10'") }
    end

    context "when request is not GET" do
      let(:request) { instance_double(RequestMock, get?: false) }
      let(:query_params) { { name_equal: "Foo" } }

      it { is_expected.not_to include("WHERE") }
    end

    context "when show action (params has :id) and record does not exist" do
      let(:params) { { id: 99 } }

      it "raises RecordNotFoundError" do
        expect { rules.process(Product.all) }.to raise_error(RestmeRails::RecordNotFoundError)
      end
    end

    context "with nested filter on a belongs_to association" do
      let(:query_params) { { establishment: { name_equal: "Foo" } } }

      it { is_expected.to include("INNER JOIN") }
      it { is_expected.to include("establishments.name = 'Foo'") }

      it "does not add DISTINCT (belongs_to never duplicates rows)" do
        is_expected.not_to include("DISTINCT")
      end
    end

    context "with nested filter on a has_many association" do
      let(:query_params) { { product_logs: { content_equal: "log" } } }

      it { is_expected.to include("INNER JOIN") }
      it { is_expected.to include("product_logs.content = 'log'") }

      it "adds DISTINCT to prevent duplicate rows" do
        is_expected.to include("DISTINCT")
      end
    end

    context "when same association is filtered with two different filter types" do
      # Both :equal and :like on the same :name field (declared in NESTED_FILTERABLE_FIELDS)
      let(:query_params) { { establishment: { name_equal: "Foo", name_like: "oo" } } }

      it "generates only one INNER JOIN for the association" do
        expect(sql.scan("INNER JOIN").count).to eq(1)
      end

      it { is_expected.to include("establishments.name = 'Foo'") }
      it { is_expected.to match(/ILIKE '%oo%'/) }
    end
  end

  describe "#errors" do
    subject(:errors) { rules.errors }

    context "when all filter fields are declared in FILTERABLE_FIELDS" do
      let(:query_params) { { name_equal: "Foo" } }

      it { is_expected.to be_nil }
      it { expect { errors }.not_to change(scope_error_instance, :scope_errors) }
    end

    context "when filter field is not in FILTERABLE_FIELDS" do
      let(:query_params) { { unknown_field_equal: "value" } }

      it { is_expected.to eq(true) }

      it "registers the unknown field as an error" do
        errors
        expect(scope_error_instance.scope_errors).not_to be_empty
      end

      it "sets scope status to :bad_request" do
        errors
        expect(scope_error_instance.scope_status).to eq(:bad_request)
      end

      it "includes the unknown field in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(:unknown_field_equal)
      end
    end

    context "when no filter params are provided" do
      it { is_expected.to be_nil }
    end

    context "when nested filter field is declared in NESTED_FILTERABLE_FIELDS" do
      let(:query_params) { { establishment: { name_equal: "Foo" } } }

      it { is_expected.to be_nil }
    end

    context "when nested filter field is NOT declared in NESTED_FILTERABLE_FIELDS" do
      let(:query_params) { { establishment: { code_equal: "ABC" } } }

      it { is_expected.to eq(true) }

      it "includes the undeclared nested field in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(:"establishment[code_equal]")
      end

      it "sets scope status to :bad_request" do
        errors
        expect(scope_error_instance.scope_status).to eq(:bad_request)
      end
    end
  end
end
