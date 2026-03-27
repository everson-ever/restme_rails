# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Filter::Types::EqualFilterable do
  subject(:filterable) { described_class.new(context:) }

  let(:context) { instance_double(RestmeRails::Context, model_class: Product) }

  describe "#filter" do
    subject(:sql) { filterable.filter(Product.all, filter_serialized).to_sql }

    context "when filtering by a single field" do
      let(:filter_serialized) { { name: "Foo" } }

      it { is_expected.to include("products.name = 'Foo'") }
    end

    context "when filtering by multiple fields" do
      let(:filter_serialized) { { name: "Foo", code: "A" } }

      it { is_expected.to include("products.name = 'Foo'") }
      it { is_expected.to include("products.code = 'A'") }
    end

    context "when filtering by id" do
      let(:filter_serialized) { { id: 42 } }

      it { is_expected.to include("products.id = 42") }
    end

    context "when filtering by establishment_id" do
      let(:filter_serialized) { { establishment_id: 10 } }

      it { is_expected.to include("products.establishment_id = 10") }
    end
  end
end
