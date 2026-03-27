# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Filter::Types::LikeFilterable do
  subject(:filterable) { described_class.new(context:) }

  let(:context) { instance_double(RestmeRails::Context, model_class: Product) }

  describe "#filter" do
    subject(:sql) { filterable.filter(Product.all, filter_serialized).to_sql }

    context "when filtering by name" do
      let(:filter_serialized) { { name: "foo" } }

      it { is_expected.to include("CAST(products.name AS TEXT) ILIKE '%foo%'") }
    end

    context "when filtering by code" do
      let(:filter_serialized) { { code: "abc" } }

      it { is_expected.to include("CAST(products.code AS TEXT) ILIKE '%abc%'") }
    end

    context "when filtering by multiple fields" do
      let(:filter_serialized) { { name: "foo", code: "bar" } }

      it { is_expected.to include("CAST(products.name AS TEXT) ILIKE '%foo%'") }
      it { is_expected.to include("CAST(products.code AS TEXT) ILIKE '%bar%'") }
    end
  end
end
