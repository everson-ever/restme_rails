# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Update::Rules do
  subject(:rules) { described_class.new(context:) }

  let(:record) { Product.new(id: 42, name: "Old Name", code: "old_code") }
  let(:user) { User.new(role: "manager") }

  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      action_name: :update,
      current_user: user,
      current_user_roles: [:manager],
      controller_params_serialized: { name: "New Name" },
      params: { id: record.id }
    )
  end

  before do
    allow(Product).to receive(:find_by).with(id: record.id).and_return(record)
    allow(record).to receive(:save).and_return(true)
    allow(record).to receive(:errors).and_return(instance_double(ActiveModel::Errors, blank?: true))
  end

  describe "#update" do
    subject(:update) { rules.update }

    context "when record exists and scope is allowed" do
      it { is_expected.to be_a(Product) }

      it "assigns new attributes to the record" do
        update
        expect(record.name).to eq("New Name")
      end
    end

    context "with custom params" do
      subject(:update) { rules.update(custom_params: { code: "custom_code" }) }

      it "merges custom params into the assigned attributes" do
        update
        expect(record.code).to eq("custom_code")
      end
    end

    context "when record is not found" do
      before { allow(Product).to receive(:find_by).with(id: record.id).and_return(nil) }

      it { expect { update }.to raise_error(RestmeRails::RecordNotFoundError) }
    end

    context "when scope is not allowed" do
      before { allow(rules).to receive(:update_scope?).and_return(false) }

      it { is_expected.to eq({ errors: ["Unscoped"] }) }
    end

    context "when validation fails after save" do
      let(:error_messages) { { name: ["can't be blank"] } }
      let(:errors_double) { instance_double(ActiveModel::Errors, blank?: false, messages: error_messages) }

      before do
        allow(record).to receive(:errors).and_return(errors_double)
      end

      it { is_expected.to eq({ errors: { name: ["can't be blank"] } }) }
    end

    context "when action is not in RESTME_UPDATE_ACTIONS_RULES" do
      let(:context) do
        instance_double(
          RestmeRails::Context,
          model_class: Product,
          action_name: :other_action,
          current_user: user,
          current_user_roles: [:manager],
          controller_params_serialized: { name: "New Name" },
          params: { id: record.id }
        )
      end

      it { is_expected.to be_a(Product) }
    end
  end

  describe "#update_status" do
    context "when update succeeds" do
      before { rules.update }

      it { expect(rules.update_status).to eq(:ok) }
    end

    context "when validation fails" do
      let(:error_messages) { { name: ["can't be blank"] } }
      let(:errors_double) { instance_double(ActiveModel::Errors, blank?: false, messages: error_messages) }

      before do
        allow(record).to receive(:errors).and_return(errors_double)
        rules.update
      end

      it { expect(rules.update_status).to eq(:unprocessable_content) }
    end
  end
end
