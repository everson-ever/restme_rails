# frozen_string_literal: true

RSpec.describe RestmeRails::UserRolesResolver do
  describe "#current_user_roles" do
    subject(:current_user_roles) { described_class.new(current_user:).current_user_roles }

    context "when current_user is nil" do
      let(:current_user) { nil }

      it { is_expected.to eq([]) }
    end

    context "when user role is a string" do
      let(:current_user) { User.new(role: "admin") }

      it { is_expected.to eq([:admin]) }
    end

    context "when user role is a symbol" do
      let(:current_user) { User.new(role: :manager) }

      it { is_expected.to eq([:manager]) }
    end

    context "when user role has leading/trailing whitespace" do
      let(:current_user) { User.new(role: "  super_admin  ") }

      it { is_expected.to eq([:super_admin]) }
    end

    context "when user role is uppercase" do
      let(:current_user) { User.new(role: "ADMIN") }

      it { is_expected.to eq([:admin]) }
    end

    context "when user responds to roles (array)" do
      let(:current_user) { User.new(roles: %w[admin manager]) }

      before { RestmeRails::Configuration.user_role_field = :roles }

      after { RestmeRails::Configuration.user_role_field = :role }

      it { is_expected.to eq(%i[admin manager]) }
    end

    context "when user roles array has duplicates" do
      let(:current_user) { User.new(roles: %w[admin admin manager]) }

      before { RestmeRails::Configuration.user_role_field = :roles }

      after { RestmeRails::Configuration.user_role_field = :role }

      it { is_expected.to eq(%i[admin manager]) }
    end

    context "when user does not respond to the role field" do
      let(:current_user) { double("User") }

      it { is_expected.to eq([]) }
    end
  end
end
