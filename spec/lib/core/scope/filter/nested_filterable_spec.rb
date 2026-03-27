# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Filter::NestedFilterable do
  subject(:filterable) { described_class.new(context:) }

  let(:context) { instance_double(RestmeRails::Context, model_class: Product) }

  describe "#filter" do
    subject(:sql) { filterable.filter(Product.all, :establishment, filter_type, fields).to_sql }

    context "when filter_type is :equal" do
      let(:filter_type) { :equal }
      let(:fields) { { name: "Foo" } }

      it { is_expected.to include("INNER JOIN") }
      it { is_expected.to include("establishments") }
      it { is_expected.to include("establishments.name = 'Foo'") }
    end

    context "when filter_type is :like" do
      let(:filter_type) { :like }
      let(:fields) { { name: "oo" } }

      it { is_expected.to match(/ILIKE '%oo%'/) }
    end

    context "when filter_type is :bigger_than" do
      let(:filter_type) { :bigger_than }
      let(:fields) { { id: 5 } }

      it { is_expected.to include("establishments.id > 5") }
    end

    context "when filter_type is :less_than" do
      let(:filter_type) { :less_than }
      let(:fields) { { id: 10 } }

      it { is_expected.to include("establishments.id < 10") }
    end

    context "when filter_type is :bigger_than_or_equal_to" do
      let(:filter_type) { :bigger_than_or_equal_to }
      let(:fields) { { id: 3 } }

      it { is_expected.to include("establishments.id >= 3") }
    end

    context "when filter_type is :less_than_or_equal_to" do
      let(:filter_type) { :less_than_or_equal_to }
      let(:fields) { { id: 7 } }

      it { is_expected.to include("establishments.id <= 7") }
    end

    context "when filter_type is :in" do
      let(:filter_type) { :in }
      let(:fields) { { id: "1,2,3" } }

      it { is_expected.to include("establishments.id IN") }
    end
  end

  describe "#apply_where" do
    subject(:sql) { filterable.apply_where(Product.all, :establishment, filter_type, fields).to_sql }

    let(:filter_type) { :equal }
    let(:fields) { { name: "Foo" } }

    it "does not add a JOIN" do
      is_expected.not_to include("INNER JOIN")
    end

    it "applies the WHERE clause" do
      is_expected.to include("establishments.name = 'Foo'")
    end

    context "when filter_type is :like" do
      let(:filter_type) { :like }
      let(:fields) { { name: "oo" } }

      it { is_expected.to match(/ILIKE '%oo%'/) }
      it { is_expected.not_to include("INNER JOIN") }
    end

    context "when multiple fields are given" do
      let(:fields) { { name: "Foo", id: 1 } }

      it { is_expected.to include("establishments.name = 'Foo'") }
      it { is_expected.to include("establishments.id = 1") }
    end
  end

  # Item 5: INNER JOIN excludes records with a NULL foreign key.
  # This is intentional: filtering by an associated field only makes sense
  # for records that actually have that association.
  describe "NULL association behaviour (INNER JOIN semantics)" do
    before do
      establishment = Establishment.create!(name: "Foo")
      Product.create!(name: "with_establishment", establishment_id: establishment.id)
      Product.create!(name: "no_establishment",   establishment_id: nil)
    end

    it "excludes products with no establishment when filtering by establishment field" do
      scope = filterable.filter(Product.all, :establishment, :equal, { name: "Foo" })
      names = scope.pluck(:name)

      expect(names).to include("with_establishment")
      expect(names).not_to include("no_establishment")
    end

    it "returns zero results when no record matches the filter (including NULL ones)" do
      scope = filterable.filter(Product.all, :establishment, :equal, { name: "NonExistent" })

      expect(scope.count).to eq(0)
    end
  end

  describe "JOIN deduplication" do
    # Rails automatically deduplicates symbol-based JOINs at the Arel level,
    # so filter called twice on the same association still produces one JOIN.
    # apply_where is the safe API when the JOIN is already present.
    it "Rails deduplicates symbol JOINs: filter twice on same assoc produces one JOIN" do
      scope = filterable.filter(Product.all, :establishment, :equal, { name: "Foo" })
      scope = filterable.filter(scope, :establishment, :like, { name: "oo" })

      expect(scope.to_sql.scan("INNER JOIN").count).to eq(1)
    end

    it "apply_where on an already-joined scope adds no extra JOIN" do
      scope = Product.all.joins(:establishment)
      scope = filterable.apply_where(scope, :establishment, :equal, { name: "Foo" })
      scope = filterable.apply_where(scope, :establishment, :like, { name: "oo" })

      expect(scope.to_sql.scan("INNER JOIN").count).to eq(1)
    end

    it "apply_where applies all WHERE clauses without JOIN" do
      scope = Product.all.joins(:establishment)
      scope = filterable.apply_where(scope, :establishment, :equal, { name: "Foo" })

      expect(scope.to_sql).to include("establishments.name = 'Foo'")
      expect(scope.to_sql.scan("INNER JOIN").count).to eq(1)
    end
  end
end
