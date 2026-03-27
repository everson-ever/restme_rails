# frozen_string_literal: true

RSpec.describe RestmeRails::ScopeError do
  subject(:scope_error) { described_class.new }

  describe "#scope_errors" do
    it { expect(scope_error.scope_errors).to eq([]) }
  end

  describe "#scope_status" do
    it { expect(scope_error.scope_status).to eq(:ok) }
  end

  describe "#add_error" do
    subject { scope_error.scope_errors }

    before { scope_error.add_error("Something went wrong") }

    it { is_expected.to include("Something went wrong") }
    it { expect(scope_error.scope_errors.size).to eq(1) }

    context "when adding multiple errors" do
      before { scope_error.add_error("Another error") }

      it { is_expected.to eq(["Something went wrong", "Another error"]) }
    end
  end

  describe "#add_status" do
    subject { scope_error.scope_status }

    before { scope_error.add_status(:bad_request) }

    it { is_expected.to eq(:bad_request) }

    context "when status is overwritten" do
      before { scope_error.add_status(:unprocessable_content) }

      it { is_expected.to eq(:unprocessable_content) }
    end
  end
end
