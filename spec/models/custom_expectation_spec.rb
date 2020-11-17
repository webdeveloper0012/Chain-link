describe CustomExpectation, type: :model do

  let(:body) { Hashie::Mash.new(payment_expectation_hash) }
  let(:expectation) { CustomExpectation.new body: body }

  describe "validations" do
    it { is_expected.to have_valid(:comparison).when('===', '<', '>', 'contains') }
    it { is_expected.not_to have_valid(:endpoint).when(nil, '', '>=', '<=') }

    it { is_expected.to have_valid(:endpoint).when('https://bitstamp.net/api/ticker/', 'http://example.net/api?foo=bar|baz') }
    it { is_expected.not_to have_valid(:endpoint).when(nil, '', 'ftp://bitstamp.net/api/ticker/', 'https://bit stamp.net/api/ticker/') }

    it { is_expected.to have_valid(:field_list).when('recent', 'recent?!?0?!?high') }
    it { is_expected.not_to have_valid(:field_list).when(nil, '') }

    it { is_expected.to have_valid(:final_value).when('recent', '0', '1.0004') }
    it { is_expected.not_to have_valid(:final_value).when(nil, '') }
  end

  describe "after create" do
    let(:expectation) { factory_build :custom_expectation }

    it "queues up a job to check the term's status" do
      expect(expectation).to receive_message_chain(:delay, :check_status)

      expectation.save
    end
  end

  describe "#fields" do
    let(:expectation) { factory_create :custom_expectation }

    it "converts the array into a string joined by the delimiter" do
      expect {
        expectation.update_attributes(fields: 'b')
      }.to change {
        expectation.reload.field_list
      }.to(['b'].to_json).and change {
        expectation.fields
      }.to(['b'])
    end
  end

  describe "#mark_completed!" do
    let!(:term) { factory_create :term, expectation: assignment }
    let(:assignment) { factory_create :assignment, subtasks: [subtask] }
    let(:subtask) { factory_build :subtask, adapter: expectation, assignment: nil }
    let(:expectation) { factory_create :custom_expectation }

    context "when there are successful API results" do
      before do
        expectation.api_results.create!(success: true)
      end

      it "updates the term" do
        expect_any_instance_of(Term).to receive(:update_status) do |receiver, status|
          expect(receiver).to eq(term)
          expect(status).to eq(Term::COMPLETED)
        end

        expectation.mark_completed!
      end
    end

    context "when there are not successful API results" do
      it "updates the term" do
        expect(term).not_to receive(:update_status)

        expectation.mark_completed!
      end
    end
  end

end
