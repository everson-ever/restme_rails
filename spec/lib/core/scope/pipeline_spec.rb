# frozen_string_literal: true

RSpec.describe RestmeRails::Core::Scope::Pipeline do
  subject(:pipeline) { described_class.new(steps) }

  let(:initial_scope) { double("initial_scope") }
  let(:intermediate_scope) { double("intermediate_scope") }
  let(:final_scope) { double("final_scope") }

  let(:step_a) { double("StepA", process: intermediate_scope, errors: nil) }
  let(:step_b) { double("StepB", process: final_scope, errors: nil) }
  let(:steps) { [step_a, step_b] }

  describe "#call" do
    subject(:call) { pipeline.call(initial_scope) }

    it "passes the initial scope to the first step" do
      call
      expect(step_a).to have_received(:process).with(initial_scope)
    end

    it "passes the result of the first step to the second step" do
      call
      expect(step_b).to have_received(:process).with(intermediate_scope)
    end

    it "returns the result of the last step" do
      expect(call).to eq(final_scope)
    end

    context "with a single step" do
      let(:steps) { [step_a] }

      it { is_expected.to eq(intermediate_scope) }
    end

    context "with no steps" do
      let(:steps) { [] }

      it { is_expected.to eq(initial_scope) }
    end
  end

  describe "#check_scope_errors" do
    subject(:check_scope_errors) { pipeline.check_scope_errors }

    it "calls errors on each step" do
      check_scope_errors
      expect(step_a).to have_received(:errors)
      expect(step_b).to have_received(:errors)
    end

    it "is memoized and only calls errors once per step" do
      pipeline.check_scope_errors
      pipeline.check_scope_errors

      expect(step_a).to have_received(:errors).once
      expect(step_b).to have_received(:errors).once
    end
  end
end
