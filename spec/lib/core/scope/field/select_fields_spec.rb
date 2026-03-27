# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Field::SelectFields do
  subject(:select_fields) { described_class.new(context:) }

  let(:context) do
    instance_double(RestmeRails::Context, model_class: Product, query_params: query_params)
  end

  let(:query_params) { {} }

  describe "#model_fields_select" do
    subject { select_fields.model_fields_select }

    context "when no params are present" do
      it { is_expected.to eq(Product.attribute_names) }
    end

    context "when fields_select is provided" do
      let(:query_params) { { fields_select: "id,name" } }

      it { is_expected.to include("id", "name") }
    end

    context "when MODEL_FIELDS_SELECT is defined" do
      before { ProductRules::Field::Rules.const_set(:MODEL_FIELDS_SELECT, %i[id establishment_id]) }
      after  { ProductRules::Field::Rules.send(:remove_const, :MODEL_FIELDS_SELECT) }

      it { is_expected.to include("id", "establishment_id") }
    end

    context "when UNALLOWED_MODEL_FIELDS_SELECT is defined" do
      before { ProductRules::Field::Rules.const_set(:UNALLOWED_MODEL_FIELDS_SELECT, %i[code]) }
      after  { ProductRules::Field::Rules.send(:remove_const, :UNALLOWED_MODEL_FIELDS_SELECT) }

      it { is_expected.not_to include("code") }
    end
  end

  describe "#unallowed" do
    subject { select_fields.unallowed }

    context "when fields_select is blank" do
      it { is_expected.to eq([]) }
    end

    context "when all requested fields are allowed" do
      let(:query_params) { { fields_select: "id,name" } }

      it { is_expected.to eq([]) }
    end

    context "when a requested field is not a model attribute" do
      let(:query_params) { { fields_select: "id,nonexistent_field" } }

      it { is_expected.to eq([:nonexistent_field]) }
    end
  end

  describe "#process" do
    subject(:sql) { select_fields.process(Product.all).to_sql }

    context "when no fields_select param" do
      it { is_expected.to include("SELECT") }
    end

    context "when fields_select specifies id and name" do
      let(:query_params) { { fields_select: "id,name" } }

      it { is_expected.to include("\"products\".\"id\"") }
      it { is_expected.to include("\"products\".\"name\"") }
      it { is_expected.not_to include("\"products\".\"code\"") }
    end

    # Item 3: Rails qualifies column names with the table even when a JOIN is
    # present. Both products and establishments have a "name" column — no
    # PG::AmbiguousColumn error is raised and the SELECT stays unambiguous.
    context "when a nested-filter JOIN is already on the scope" do
      subject(:sql) { select_fields.process(Product.all.joins(:establishment)).to_sql }

      let(:query_params) { { fields_select: "id,name" } }

      it "qualifies id with the model table name" do
        is_expected.to include("\"products\".\"id\"")
      end

      it "qualifies name with the model table name (not establishments.name)" do
        is_expected.to include("\"products\".\"name\"")
        is_expected.not_to match(/"establishments"\."name"/)
      end
    end
  end
end
