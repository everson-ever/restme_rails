# frozen_string_literal: true

RSpec.describe RestmeRails::Error do
  subject { described_class.new("generic error") }

  it { is_expected.to be_a(StandardError) }
  it { expect(subject.message).to eq("generic error") }
end

RSpec.describe RestmeRails::NotAuthorizedError do
  subject { described_class.new("not allowed") }

  it { is_expected.to be_a(RestmeRails::Error) }
  it { expect(subject.message).to eq("not allowed") }
end

RSpec.describe RestmeRails::RecordNotFoundError do
  subject { described_class.new("not found") }

  it { is_expected.to be_a(RestmeRails::Error) }
  it { expect(subject.message).to eq("not found") }
end

RSpec.describe RestmeRails::MissingAttributeError do
  subject { described_class.new("missing") }

  it { is_expected.to be_a(RestmeRails::Error) }
  it { expect(subject.message).to eq("missing") }
end
