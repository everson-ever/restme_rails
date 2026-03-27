# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Sort::Rules do
  subject(:rules) { described_class.new(context:, scope_error_instance:) }

  let(:scope_error_instance) { RestmeRails::ScopeError.new }
  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      query_params: query_params,
      request: request
    )
  end
  let(:request) { instance_double(RequestMock, get?: true) }
  let(:query_params) { {} }

  describe "#process" do
    subject(:process) { rules.process(Product.all) }

    context "when no sort params are present" do
      it "returns the scope unchanged" do
        expect(process.to_sql).not_to include("ORDER BY")
      end
    end

    context "when sorting by a valid field ascending" do
      let(:query_params) { { name_sort: "asc" } }

      it { expect(process.to_sql).to include("ORDER BY") }
      it { expect(process.to_sql).to include('"products"."name" ASC') }
    end

    context "when sorting by a valid field descending" do
      let(:query_params) { { name_sort: "desc" } }

      it { expect(process.to_sql).to include('"products"."name" DESC') }
    end

    context "when sort direction is invalid" do
      let(:query_params) { { name_sort: "invalid_direction" } }

      it "defaults to ascending" do
        expect(process.to_sql).to include('"products"."name" ASC')
      end
    end

    context "when the request is not GET" do
      let(:request) { instance_double(RequestMock, get?: false) }
      let(:query_params) { { name_sort: "asc" } }

      it "returns the scope unchanged" do
        expect(process.to_sql).not_to include("ORDER BY")
      end
    end

    context "when sorting by :id (always allowed)" do
      let(:query_params) { { id_sort: "desc" } }

      it { expect(process.to_sql).to include('"products"."id" DESC') }
    end

    # Item 4: Rails qualifies ORDER BY with the model table name even when a
    # JOIN is present. Both products and establishments have a "name" column —
    # no PG::AmbiguousColumn error is raised and the ORDER BY stays unambiguous.
    context "when a nested-filter JOIN is already on the scope" do
      subject(:process) { rules.process(Product.all.joins(:establishment)) }

      let(:query_params) { { name_sort: "asc" } }

      it "qualifies ORDER BY with the model table name" do
        expect(process.to_sql).to include('"products"."name" ASC')
      end

      it "does not order by the joined table column" do
        expect(process.to_sql).not_to match(/"establishments"\."name"/)
      end
    end
  end

  describe "#errors" do
    subject(:errors) { rules.errors }

    context "when sort params are empty" do
      it { is_expected.to be_nil }
      it { expect { errors }.not_to change(scope_error_instance, :scope_errors) }
    end

    context "when sorting by a valid field" do
      let(:query_params) { { name_sort: "asc" } }

      it { is_expected.to be_nil }
    end

    context "when sorting by an unknown field" do
      let(:query_params) { { unknown_field_sort: "asc" } }

      it { is_expected.to eq(true) }

      it "adds an error to scope_error_instance" do
        errors
        expect(scope_error_instance.scope_errors).not_to be_empty
      end

      it "sets scope status to :bad_request" do
        errors
        expect(scope_error_instance.scope_status).to eq(:bad_request)
      end

      it "includes the unknown field in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(:unknown_field)
      end
    end
  end
end
