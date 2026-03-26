# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Create::Rules do
  subject(:rules) { described_class.new(context:) }

  let(:context) do
    instance_double(
      RestmeRails::Context,
      controller_params_serialized: {},
      model_class: Product,
      current_user: nil,
      current_user_roles: [],
      action_name: :create
    )
  end

  describe "#errors" do
    subject(:errors) { rules.send(:errors) }

    context "when action is not scoped" do
      before { allow(rules).to receive(:scoped_action?).and_return(false) }

      it { is_expected.to be_nil }
    end

    context "when action is scoped but scope is not allowed" do
      before do
        allow(rules).to receive(:scoped_action?).and_return(true)
        allow(rules).to receive(:scope_allowed?).and_return(false)
      end

      it { is_expected.to eq({ errors: ["Unscoped"] }) }
    end

    context "when action is scoped, allowed, and instance has no errors" do
      let(:instance_errors) { instance_double(ActiveModel::Errors, blank?: true) }
      let(:record) { instance_double(Product, errors: instance_errors) }

      before do
        allow(rules).to receive(:scoped_action?).and_return(true)
        allow(rules).to receive(:scope_allowed?).and_return(true)
        allow(rules).to receive(:instance).and_return(record)
      end

      it { is_expected.to be_nil }
    end

    context "when action is scoped, allowed, and instance has errors" do
      let(:error_messages) { { name: ["can't be blank"] } }
      let(:instance_errors) { instance_double(ActiveModel::Errors, blank?: false, messages: error_messages) }
      let(:record) { instance_double(Product, errors: instance_errors) }

      before do
        allow(rules).to receive(:scoped_action?).and_return(true)
        allow(rules).to receive(:scope_allowed?).and_return(true)
        allow(rules).to receive(:instance).and_return(record)
      end

      it { is_expected.to eq({ errors: { name: ["can't be blank"] } }) }
    end

    describe "memoization" do
      before { allow(rules).to receive(:scoped_action?).and_return(false) }

      it "evaluates the errors logic only once across multiple calls" do
        rules.send(:errors)
        rules.send(:errors)
        rules.send(:errors)

        expect(rules).to have_received(:scoped_action?).once
      end

      it "returns the same result on subsequent calls" do
        first_call = rules.send(:errors)
        second_call = rules.send(:errors)

        expect(first_call).to eq(second_call)
      end
    end
  end
end
