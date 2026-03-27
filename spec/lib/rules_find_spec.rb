# frozen_string_literal: true

RSpec.describe RestmeRails::RulesFind do
  describe "#rule_class" do
    subject(:rule_class) { described_class.new(klass:, rule_context:).rule_class }

    context "when the rule class exists" do
      let(:klass) { Product }
      let(:rule_context) { "Create" }

      it { is_expected.to eq(ProductRules::Create::Rules) }
    end

    context "when the rule class does not exist" do
      let(:klass) { Establishment }
      let(:rule_context) { "Create" }

      it { is_expected.to be_nil }
    end

    context "when rule_context is given as a symbol" do
      let(:klass) { Product }
      let(:rule_context) { :create }

      it { is_expected.to eq(ProductRules::Create::Rules) }
    end

    context "for the Scope context" do
      let(:klass) { Product }
      let(:rule_context) { "Scope" }

      it { is_expected.to eq(ProductRules::Scope::Rules) }
    end

    context "for the Update context" do
      let(:klass) { Product }
      let(:rule_context) { "Update" }

      it { is_expected.to eq(ProductRules::Update::Rules) }
    end
  end
end
