# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Paginate::Rules do
  subject(:rules) { described_class.new(context:, scope_error_instance:) }

  let(:scope_error_instance) { RestmeRails::ScopeError.new }
  let(:context) { instance_double(RestmeRails::Context, params: params) }
  let(:params) { {} }

  describe "#process" do
    subject(:sql) { rules.process(Product.all).to_sql }

    context "with default page and per_page" do
      it { is_expected.to include("LIMIT #{RestmeRails::Configuration.pagination_default_per_page}") }
      it { is_expected.to include("OFFSET 0") }
    end

    context "with custom page" do
      let(:params) { { page: "3", per_page: "5" } }

      it { is_expected.to include("LIMIT 5") }
      it { is_expected.to include("OFFSET 10") }
    end

    context "with page 2 and default per_page" do
      let(:params) { { page: "2" } }

      it { is_expected.to include("OFFSET #{RestmeRails::Configuration.pagination_default_per_page}") }
    end
  end

  describe "#page_no" do
    subject { rules.page_no }

    context "when page param is not present" do
      it { is_expected.to eq(RestmeRails::Configuration.pagination_default_page) }
    end

    context "when page param is provided" do
      let(:params) { { page: "4" } }

      it { is_expected.to eq(4) }
    end
  end

  describe "#pages" do
    subject { rules.pages(scope) }

    let(:scope) { double("scope", size: total) }

    context "when total items divide evenly" do
      let(:params) { { per_page: "5" } }
      let(:total) { 10 }

      it { is_expected.to eq(2) }
    end

    context "when total items do not divide evenly" do
      let(:params) { { per_page: "2" } }
      let(:total) { 3 }

      it { is_expected.to eq(2) }
    end

    context "when there are no items" do
      let(:params) { {} }
      let(:total) { 0 }

      it { is_expected.to eq(0) }
    end
  end

  describe "#total_items" do
    subject { rules.total_items(scope) }

    let(:scope) { double("scope", size: 7) }

    it { is_expected.to eq(7) }
  end

  describe "#errors" do
    subject(:errors) { rules.errors }

    context "when per_page is within the allowed limit" do
      let(:params) { { per_page: "10" } }

      it { is_expected.to be_nil }
      it { expect { errors }.not_to change(scope_error_instance, :scope_errors) }
    end

    context "when per_page exceeds the maximum allowed value" do
      let(:params) { { per_page: "999" } }

      it { is_expected.to eq(true) }

      it "adds an error to scope_error_instance" do
        errors
        expect(scope_error_instance.scope_errors).not_to be_empty
      end

      it "sets scope status to :bad_request" do
        errors
        expect(scope_error_instance.scope_status).to eq(:bad_request)
      end

      it "includes the max per_page value in the error body" do
        errors
        expect(scope_error_instance.scope_errors.first[:body]).to include(
          per_page_max_value: RestmeRails::Configuration.pagination_max_per_page
        )
      end
    end
  end
end
