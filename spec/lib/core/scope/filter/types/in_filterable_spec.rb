# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Filter::Types::InFilterable do
  subject(:filterable) { described_class.new(context:) }

  let(:context) { instance_double(RestmeRails::Context, model_class: Product) }

  describe "#filter" do
    subject(:sql) { filterable.filter(Product.all, filter_serialized).to_sql }

    context "when filtering by name with comma-separated values" do
      let(:filter_serialized) { { name: "Foo,Bar" } }

      it { is_expected.to include("products.name IN ('Foo', 'Bar')") }
    end

    context "when filtering by a single value" do
      let(:filter_serialized) { { name: "Foo" } }

      it { is_expected.to include("products.name IN ('Foo')") }
    end

    context "when filtering by establishment_id" do
      # Values are split from a string so they remain strings; AR quotes them as ('1', '2', '3')
      let(:filter_serialized) { { establishment_id: "1,2,3" } }

      it { is_expected.to include("products.establishment_id IN ('1', '2', '3')") }
    end

    context "when values have surrounding whitespace" do
      let(:filter_serialized) { { name: "Foo , Bar" } }

      it { is_expected.to include("products.name IN ('Foo', 'Bar')") }
    end
  end
end
