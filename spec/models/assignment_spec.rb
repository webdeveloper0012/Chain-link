describe Assignment, type: :model do

  describe "validations" do
    it { is_expected.to have_valid(:end_at).when(Time.at(1), Time.now) }
    it { is_expected.not_to have_valid(:end_at).when(0, nil, Time.at(0)) }

    it { is_expected.to have_valid(:subtasks).when([factory_build(:subtask, assignment: nil)]) }
    it { is_expected.not_to have_valid(:subtasks).when([]) }

    it { is_expected.to have_valid(:coordinator).when(factory_create(:coordinator)) }
    it { is_expected.not_to have_valid(:coordinator).when(nil) }

    it { is_expected.to have_valid(:status).when('completed', 'failed', 'in progress') }
    it { is_expected.not_to have_valid(:status).when('other') }

    it { is_expected.to have_valid(:term).when(factory_build(:term), nil) }

    context "when the adapter gets an error" do
      let(:assignment) { factory_build :assignment }
      let(:subtask) { assignment.subtasks.first }
      let(:remote_error_message) { 'big errors. great job.' }

      it "includes the adapter error" do
        expect(subtask.adapter).to receive(:start)
          .with(subtask)
          .and_return(create_assignment_response errors: [remote_error_message])

        assignment.save

        expect(assignment.errors.full_messages).to include("Adapter##{subtask.index} Error: #{remote_error_message}")
      end
    end

    context "when the term start date is before the end date" do
      it "is not valid" do
        term = Term.new start_at: 1.day.from_now, end_at: 1.day.ago

        expect(term).not_to be_valid
        expect(term.errors.full_messages).to include("Start at must be before end at")
      end
    end

    context "when the assignment is no longer in progress" do
      let(:assignment) { factory_create :failed_assignment }

      it "does not allow the status to be updated" do
        expect(assignment.update_attributes status: Assignment::COMPLETED).to be_falsey

        expect(assignment.errors.full_messages).to include("Status is no longer in progress")
      end
    end
  end

  describe "on create" do
    let(:assignment) { factory_build :assignment }

    it "assigns an XID" do
      expect {
        assignment.tap(&:save).reload
      }.to change {
        assignment.xid
      }.from(nil)
    end

    it "does NOT create a schedule" do
      expect {
        assignment.tap(&:save).reload
      }.not_to change {
        assignment.schedule
      }.from(nil)
    end

    context "when the assignment has a schedule" do
      let(:assignment) { factory_build :assignment, schedule_attributes: schedule_params }
      let(:schedule_params) { factory_attrs :assignment_schedule, assignment: nil }

      it "creates a schedule" do
        expect {
          assignment.save
        }.to change {
          AssignmentSchedule.count
        }

        expect(assignment.schedule).to eq(AssignmentSchedule.last)
      end
    end

    it "creates a snapshot" do
      expect_any_instance_of(Assignment).to receive(:check_status) do |receiver|
        expect(receiver).to eq(assignment)
      end

      run_generated_jobs { assignment.save }
    end
  end

  describe ".expired" do
    let!(:in_progress_future) { factory_create :assignment, status: Assignment::IN_PROGRESS, end_at: 1.minute.from_now }
    let!(:in_progress_passed) { factory_create :assignment, status: Assignment::IN_PROGRESS, end_at: 1.minute.ago }
    let!(:completed_passed) { factory_create :assignment, status: Assignment::COMPLETED, end_at: 1.minute.ago }
    let!(:failed_passed) { factory_create :assignment, status: Assignment::FAILED, end_at: 1.minute.ago }

    it "returns in progress assignments past their end at time" do
      expired = Assignment.expired

      expect(expired).to include(in_progress_passed)
      expect(expired).not_to include(in_progress_future)
      expect(expired).not_to include(completed_passed)
      expect(expired).not_to include(failed_passed)
    end
  end

  describe ".termless" do
    let(:with_term) { factory_create(:term, expectation: factory_build(:assignment)).expectation }
    let(:without_term) { factory_create :assignment, term: nil }

    it "returns only assignments that do not have a term" do
      termless = Assignment.termless

      expect(termless).to include(without_term)
      expect(termless).not_to include(with_term)
    end
  end

  describe "#check_status" do
    let(:assignment) { factory_create :assignment }

    it "creates a new status record" do
      expect {
        assignment.check_status
      }.to change {
        assignment.snapshots.count
      }.by(+1)
    end

    context "when not all of the substasks are ready" do
      before do
        factory_create :uninitialized_subtask, assignment: assignment
        assignment.reload
      end

      it "does not create a new snapshot" do
        expect {
          assignment.check_status
        }.not_to change {
          assignment.reload.snapshots.count
        }
      end
    end
  end

  describe "#close_out!" do
    let(:term) { factory_build :term }
    let(:assignment) { factory_create :assignment, term: term }
    let(:subtask) { assignment.subtasks.first }
    let(:status) { Assignment::COMPLETED }

    it "closes out via each subtask" do
      expect(subtask).to receive(:close_out!)

      assignment.close_out!
    end

    it "moves the assignment into the failed state" do
      expect {
        assignment.close_out! status
      }.to change {
        assignment.status
      }.from(Assignment::IN_PROGRESS).to(status)
    end

    context "when the term is already completed" do
      before do
        assignment.term.update_attributes status: status
      end

      it "does change the assignment's state" do
        expect {
          assignment.close_out! status
        }.to change {
          assignment.status
        }
      end

      it "does not continually try to update the status" do
        expect_any_instance_of(CoordinatorClient).not_to receive(:delay)

        expect {
          assignment.close_out! status
        }.not_to change {
          Delayed::Job.count
        }
      end
    end
  end

  describe "#update_status" do
    let(:assignment) { factory_create :assignment, term: term }
    let(:status) { Assignment::COMPLETED }

    context "when the assignment does NOT have a term" do
      let(:term) { nil }

      it "creates an assignment snapshot" do
        expect {
          assignment.update_status status
        }.to change {
          assignment.snapshots.count
        }.by(+1)
      end

      it "updates the assignment's status" do
        expect {
          assignment.update_status status
        }.to change {
          assignment.status
        }.from(Assignment::IN_PROGRESS).to(Assignment::COMPLETED)
      end
    end

    context "when the assignment does have a term" do
      let(:term) { factory_create :term }

      before do
        expect(assignment.term).to receive(:update_status)
          .and_return(term_response)
      end

      context "when the status successfully updates" do
        let(:term_response) { status }

        it "creates an assignment snapshot" do
          expect {
            assignment.update_status status
          }.to change {
            assignment.snapshots.count
          }.by(+1)
        end

        it "updates the assignment's status" do
          expect {
            assignment.update_status status
          }.to change {
            assignment.status
          }.from(Assignment::IN_PROGRESS).to(Assignment::COMPLETED)
        end
      end

      context "when the status successfully does NOT update" do
        let(:term_response) { nil }

        it "does NOT create a snapshot" do
          expect {
            assignment.update_status status
          }.not_to change {
            assignment.snapshots.count
          }
        end

        it "updates the assignment's status" do
          expect {
            assignment.update_status status
          }.not_to change {
            assignment.status
          }.from(Assignment::IN_PROGRESS)
        end
      end
    end
  end

  describe "#subtask_ready" do
    let(:assignment) { factory_create :assignment }
    let(:subtask) { assignment.subtasks.first }

    context "when all of the substasks are ready" do
      before do
        subtask.update_attributes(ready: true)
        assignment.reload
      end

      it "creates a new assignment snapshot" do
        expect {
          assignment.subtask_ready(subtask)
        }.to change {
          assignment.reload.snapshots.count
        }.by(+1)
      end

      it "sends integration instructions to the coordinator" do
        expect(assignment.coordinator).to receive(:assignment_initialized)
          .with(assignment.id)

        assignment.subtask_ready(subtask)
      end

      context "and the assignment has been marked not to create an initial snapshot" do
        let(:assignment) { factory_create :assignment, skip_initial_snapshot: true }

        it "does not create a new snapshot" do
          expect {
            assignment.subtask_ready(subtask)
          }.not_to change {
            assignment.reload.snapshots.count
          }
        end
      end
    end

    context "when not all of the substasks are ready" do
      before do
        factory_create :uninitialized_subtask, assignment: assignment
        assignment.reload
      end

      it "does not create a new snapshot" do
        expect {
          assignment.subtask_ready(subtask)
        }.not_to change {
          assignment.reload.snapshots.count
        }
      end
    end
  end
end
