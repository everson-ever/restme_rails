# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Authorize::Rules do
  subject(:rules) { described_class.new(context:) }

  let(:controller_class) do
    Class.new do
      extend RestmeRails::ClassMethods

      restme_authorize_action :index,  %i[admin manager super_admin]
      restme_authorize_action :create, %i[admin super_admin]
    end
  end

  let(:bare_controller_class) do
    Class.new { extend RestmeRails::ClassMethods }
  end

  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      controller_class: controller_class,
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

    context "when user role matches the DSL declaration" do
      let(:action_name) { :index }
      let(:current_user_roles) { [:manager] }

      it { is_expected.to eq(true) }
    end

    context "when user role does not match the DSL declaration" do
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

    context "when the controller has no DSL declarations" do
      let(:context) do
        instance_double(
          RestmeRails::Context,
          model_class: Product,
          controller_class: bare_controller_class,
          action_name: :index,
          current_user: current_user,
          current_user_roles: [:manager]
        )
      end

      it { expect { authorize! }.to raise_error(RestmeRails::NotAuthorizedError) }
    end

    context "with multiple actions declared at once" do
      let(:controller_class) do
        Class.new do
          extend RestmeRails::ClassMethods

          restme_authorize_action %i[index show create], %i[admin manager]
        end
      end

      context "when user role matches" do
        let(:action_name) { :show }
        let(:current_user_roles) { [:manager] }

        it { is_expected.to eq(true) }
      end

      context "when action is not in the declaration" do
        let(:action_name) { :update }
        let(:current_user_roles) { [:admin] }

        it { expect { authorize! }.to raise_error(RestmeRails::NotAuthorizedError) }
      end
    end
  end
end
