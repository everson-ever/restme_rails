# frozen_string_literal: true

RSpec.describe RestmeRails::ModelFinder do
  describe "#model_class" do
    subject(:model_class) { described_class.new(controller_class:).model_class }

    context "when controller follows naming convention" do
      let(:controller_class) { ProductsController }

      it { is_expected.to eq(Product) }
    end

    context "when controller is for a different model" do
      let(:controller_class) { EstablishmentsController }

      it { is_expected.to eq(Establishment) }
    end

    context "when controller defines MODEL_NAME constant" do
      let(:controller_class) do
        klass = Class.new
        klass.const_set(:MODEL_NAME, "Product")
        stub_const("CustomController", klass)
        CustomController
      end

      it { is_expected.to eq(Product) }
    end

    context "when controller name is namespaced" do
      let(:controller_class) do
        stub_const("Admin::ProductsController", Class.new)
        Admin::ProductsController
      end

      it { is_expected.to eq(Product) }
    end
  end
end
