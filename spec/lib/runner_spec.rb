# frozen_string_literal: true

RSpec.describe RestmeRails::Runner do
  subject(:runner) { described_class.new(context:) }

  let(:user) { User.new(role: "manager") }

  let(:context) do
    instance_double(
      RestmeRails::Context,
      model_class: Product,
      controller_class: ProductsController,
      action_name: :index,
      current_user: user,
      current_user_roles: [:manager],
      controller_params_serialized: {},
      params: {},
      query_params: {},
      request: instance_double(RequestMock, get?: true)
    )
  end

  describe "#authorize!" do
    subject(:authorize!) { runner.authorize! }

    it { is_expected.to eq(true) }

    it "delegates to Core::Authorize::Rules" do
      authorize_rules = instance_double(RestmeRails::Core::Authorize::Rules, authorize!: true)
      allow(RestmeRails::Core::Authorize::Rules).to receive(:new).with(context:).and_return(authorize_rules)

      authorize!

      expect(authorize_rules).to have_received(:authorize!)
    end

    it "is memoized across multiple calls" do
      authorize_rules = instance_double(RestmeRails::Core::Authorize::Rules, authorize!: true)
      allow(RestmeRails::Core::Authorize::Rules).to receive(:new).with(context:).and_return(authorize_rules)

      runner.authorize!
      runner.authorize!

      expect(authorize_rules).to have_received(:authorize!).once
    end
  end

  describe "#restme_create" do
    let(:record) { instance_double(Product) }
    let(:create_rules) do
      instance_double(RestmeRails::Core::Create::Rules, create: record, create_status: :created)
    end

    before do
      allow(RestmeRails::Core::Create::Rules).to receive(:new).with(context:).and_return(create_rules)
    end

    it "delegates to Core::Create::Rules" do
      runner.restme_create
      expect(create_rules).to have_received(:create).with(custom_params: {})
    end

    it "passes custom_params through" do
      runner.restme_create(custom_params: { quantity: 10 })
      expect(create_rules).to have_received(:create).with(custom_params: { quantity: 10 })
    end
  end

  describe "#restme_update" do
    let(:record) { instance_double(Product) }
    let(:update_rules) do
      instance_double(RestmeRails::Core::Update::Rules, update: record, update_status: :ok)
    end

    before do
      allow(RestmeRails::Core::Update::Rules).to receive(:new).with(context:).and_return(update_rules)
    end

    it "delegates to Core::Update::Rules" do
      runner.restme_update
      expect(update_rules).to have_received(:update).with(custom_params: {})
    end
  end

  describe "#scope_status" do
    subject { runner.scope_status }

    it { is_expected.to eq(:ok) }
  end
end
