# frozen_string_literal: true

RSpec.describe RestmeRails::Adapters::ControllerAdapter do
  subject(:adapter) { described_class.new(controller) }

  let(:query_parameters) { { name_equal: "foo" } }
  let(:request) { instance_double(RequestMock, query_parameters: query_parameters.stringify_keys) }
  let(:controller) do
    double(
      "Controller",
      params: { name: "foo", controller: "products", action: "index" },
      request: request,
      action_name: "index",
      class: ProductsController
    )
  end

  describe "#params" do
    subject { adapter.params }

    it { is_expected.to eq({ name: "foo", controller: "products", action: "index" }) }
  end

  describe "#query_params" do
    subject { adapter.query_params }

    it { is_expected.to eq({ name_equal: "foo" }) }
  end

  describe "#action_name" do
    subject { adapter.action_name }

    it { is_expected.to eq("index") }
  end

  describe "#controller_class" do
    subject { adapter.controller_class }

    it { is_expected.to eq(ProductsController) }
  end

  describe "#request" do
    subject { adapter.request }

    it { is_expected.to eq(request) }
  end

  context "when controller does not respond to :request" do
    let(:controller) do
      double("Controller", params: {}, action_name: "index", class: ProductsController)
    end

    describe "#query_params" do
      subject { adapter.query_params }

      it { is_expected.to eq({}) }
    end
  end
end
