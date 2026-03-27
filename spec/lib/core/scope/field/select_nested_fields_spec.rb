# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Field::SelectNestedFields do
  subject(:select_nested) { described_class.new(context:) }

  let(:context) do
    instance_double(RestmeRails::Context, model_class: Product, query_params: query_params)
  end

  let(:query_params) { {} }

  describe "#valid_nested_fields_select" do
    subject { select_nested.valid_nested_fields_select }

    context "when nested_fields_select is blank" do
      it { is_expected.to be_nil }
    end

    context "when given a comma-separated string with an allowed association" do
      let(:query_params) { { nested_fields_select: "establishment" } }

      it { is_expected.to eq({ establishment: nil }) }
    end

    context "when given a hash with field selection for an allowed association" do
      let(:query_params) { { nested_fields_select: { establishment: "id,name" } } }

      it { is_expected.to eq({ establishment: %i[id name] }) }
    end

    context "when string contains only a disallowed association" do
      let(:query_params) { { nested_fields_select: "unknown_assoc" } }

      it { is_expected.to be_nil }
    end

    context "when hash contains only a disallowed association" do
      let(:query_params) { { nested_fields_select: { unknown_assoc: "id" } } }

      it { is_expected.to be_nil }
    end

    context "when hash mixes allowed and disallowed associations" do
      let(:query_params) { { nested_fields_select: { establishment: "id", unknown_assoc: "id" } } }

      it { is_expected.to eq({ establishment: [:id] }) }
    end
  end

  describe "#unallowed" do
    subject { select_nested.unallowed }

    context "when nested_fields_select is blank" do
      it { is_expected.to eq([]) }
    end

    context "when string contains a disallowed association" do
      let(:query_params) { { nested_fields_select: "establishment,unknown_assoc" } }

      it { is_expected.to eq([:unknown_assoc]) }
    end

    context "when hash contains a disallowed association" do
      let(:query_params) { { nested_fields_select: { establishment: "id", unknown_assoc: "id" } } }

      it { is_expected.to eq([:unknown_assoc]) }
    end
  end

  describe "#process" do
    subject(:result) { select_nested.process(Product.all) }

    context "when no nested_fields_select param" do
      it { is_expected.to be_a(ActiveRecord::Relation) }
    end

    context "when a valid association is requested" do
      let(:query_params) { { nested_fields_select: "establishment" } }

      it { is_expected.to be_a(ActiveRecord::Relation) }
    end
  end

  describe "parsing" do
    subject { select_nested.send(:nested_fields_parsed) }

    context "when given a comma-separated string" do
      let(:query_params) { { nested_fields_select: "establishment,setting" } }

      it { is_expected.to eq({ establishment: nil, setting: nil }) }
    end

    context "when given a hash with multiple associations" do
      let(:query_params) { { nested_fields_select: { establishment: "id,name", setting: "id" } } }

      it { is_expected.to eq({ establishment: %i[id name], setting: [:id] }) }
    end

    context "when hash values have surrounding whitespace" do
      let(:query_params) { { nested_fields_select: { establishment: "id , name" } } }

      it { is_expected.to eq({ establishment: %i[id name] }) }
    end
  end
end
