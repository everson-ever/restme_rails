# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Filter::Types::LessThanOrEqualToFilterable do
  subject(:filterable) { described_class.new(context:) }

  let(:context) { instance_double(RestmeRails::Context, model_class: Product) }

  describe "#filter" do
    subject(:sql) { filterable.filter(Product.all, filter_serialized).to_sql }

    context "when filtering by quantity" do
      let(:filter_serialized) { { quantity: 10 } }

      it { is_expected.to include("products.quantity <= 10") }
    end

    context "when filtering by establishment_id" do
      let(:filter_serialized) { { establishment_id: 5 } }

      it { is_expected.to include("products.establishment_id <= 5") }
    end

    context "when filtering by multiple fields" do
      let(:filter_serialized) { { quantity: 20, establishment_id: 3 } }

      it { is_expected.to include("products.quantity <= 20") }
      it { is_expected.to include("products.establishment_id <= 3") }
    end
  end
end
