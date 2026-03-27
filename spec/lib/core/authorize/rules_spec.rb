# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Authorize::Rules do
  subject(:rules) { described_class.new(context:) }

  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      action_name: action_name,
      current_user: current_user,
      current_user_roles: current_user_roles
    )
  end

  let(:action_name) { :index }
  let(:current_user) { instance_double(User) }
  let(:current_user_roles) { [:manager] }

  describe "#authorize!" do
    subject(:authorize!) { rules.authorize! }

    context "when there is no current user" do
      let(:current_user) { nil }

      it { is_expected.to eq(true) }
    end

    context "when user role is allowed for the action" do
      let(:action_name) { :index }
      let(:current_user_roles) { [:manager] }

      it { is_expected.to eq(true) }
    end

    context "when user role is not allowed for the action" do
      let(:action_name) { :index }
      let(:current_user_roles) { [:unknown_role] }

      it { expect { authorize! }.to raise_error(RestmeRails::NotAuthorizedError) }
    end

    context "when the action has no rules defined" do
      let(:action_name) { :destroy }
      let(:current_user_roles) { [:manager] }

      it { expect { authorize! }.to raise_error(RestmeRails::NotAuthorizedError) }
    end

    context "when user has super_admin role" do
      let(:action_name) { :create }
      let(:current_user_roles) { [:super_admin] }

      it { is_expected.to eq(true) }
    end

    context "when model has no authorize rules class" do
      let(:context) do
        instance_double(
          RestmeRails::Context,
          model_class: Setting,
          action_name: :index,
          current_user: current_user,
          current_user_roles: [:manager]
        )
      end

      it { expect { authorize! }.to raise_error(RestmeRails::NotAuthorizedError) }
    end
  end
end
