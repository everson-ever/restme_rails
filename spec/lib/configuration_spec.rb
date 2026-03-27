# frozen_string_literal: true

RSpec.describe RestmeRails::Configuration do
  describe "defaults" do
    it { expect(described_class.current_user_variable).to eq(:current_user) }
    it { expect(described_class.user_role_field).to eq(:role) }
    it { expect(described_class.pagination_default_per_page).to eq(12) }
    it { expect(described_class.pagination_default_page).to eq(1) }
    it { expect(described_class.pagination_max_per_page).to eq(100) }
  end

  describe "when configured via RestmeRails.configure" do
    before do
      RestmeRails.configure do |config|
        config.current_user_variable = :logged_user
        config.user_role_field = :roles
        config.pagination_default_per_page = 20
        config.pagination_default_page = 2
        config.pagination_max_per_page = 50
      end
    end

    after do
      RestmeRails.configure do |config|
        config.current_user_variable = :current_user
        config.user_role_field = :role
        config.pagination_default_per_page = 12
        config.pagination_default_page = 1
        config.pagination_max_per_page = 100
      end
    end

    it { expect(described_class.current_user_variable).to eq(:logged_user) }
    it { expect(described_class.user_role_field).to eq(:roles) }
    it { expect(described_class.pagination_default_per_page).to eq(20) }
    it { expect(described_class.pagination_default_page).to eq(2) }
    it { expect(described_class.pagination_max_per_page).to eq(50) }
  end
end
