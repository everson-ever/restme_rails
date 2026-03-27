# frozen_string_literal: true

RSpec.describe RestmeRails::ParamsSerializer do
  subject(:serializer) { described_class.new(controller: controller_adapter, model_class:) }

  let(:model_class) { Product }
  let(:controller_adapter) do
    instance_double(
      RestmeRails::Adapters::ControllerAdapter,
      params: params,
      query_params: {}
    )
  end

  describe "#params_serialized" do
    subject(:params_serialized) { serializer.params_serialized }

    context "when params are flat (no model key)" do
      let(:params) { { name: "foo", code: "bar" } }

      it { is_expected.to eq({ name: "foo", code: "bar" }) }
    end

    context "when params are nested under the model key" do
      let(:params) { { product: { name: "foo", code: "bar" } } }

      it { is_expected.to eq({ name: "foo", code: "bar" }) }
    end

    context "when params include Rails routing keys" do
      let(:params) { { controller: "products", action: "create", name: "foo" } }

      it { is_expected.not_to have_key(:controller) }
      it { is_expected.not_to have_key(:action) }
      it { is_expected.to include(name: "foo") }
    end

    context "when params have flat string keys" do
      let(:params) { { "name" => "foo", "code" => "bar" } }

      it { is_expected.to eq({ name: "foo", code: "bar" }) }
    end

    context "when params have string keys nested under model key" do
      # Plain hashes use symbol lookup: hash[:product].
      # String key "product" is not found, so the full hash is returned deep-symbolized.
      let(:params) { { "product" => { "name" => "foo" } } }

      it { is_expected.to eq({ product: { name: "foo" } }) }
    end

    context "when params are empty" do
      let(:params) { {} }

      it { is_expected.to eq({}) }
    end
  end

  describe "#params" do
    subject { serializer.params }

    let(:params) { { name: "foo" } }

    it { is_expected.to eq({ name: "foo" }) }
  end

  describe "#query_params" do
    subject { serializer.query_params }

    let(:params) { {} }

    it { is_expected.to eq({}) }
  end
end
