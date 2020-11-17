describe ExternalAdapterClient, type: :model do
  let(:assignment) { factory_create :assignment, subtasks: [subtask] }
  let(:subtask) { factory_build :subtask, adapter: validator, assignment: nil }
  let(:validator) { factory_create :external_adapter }
  let(:client) { ExternalAdapterClient.new(validator) }

  describe "#create_assignment" do
    it "sends a post message to the validator client" do
      expect(ExternalAdapterClient).to receive(:post)
        .with("#{validator.url}/subtasks", {
          basic_auth: {
            password: validator.password,
            username: validator.username,
          },
          body: {
            data: subtask.parameters,
            endAt: assignment.end_at.to_i.to_s,
            taskType: subtask.task_type,
            xid: subtask.xid,
          },
        }).and_return(http_response body: {}.to_json)

      client.start_assignment subtask
    end
  end

  describe "#assignment_snapshot" do
    let(:snapshot) { factory_create :adapter_snapshot }
    let(:previous_snapshot) { factory_create :adapter_snapshot, details: {foo: 'bar'} }
    let(:subtask) { snapshot.subtask }
    let(:expected_response) { hashie({a: 1}) }

    it "sends a post message to the validator client" do
      expect(ExternalAdapterClient).to receive(:post)
        .with("#{validator.url}/subtasks/#{subtask.xid}/snapshots", {
          basic_auth: {
            password: validator.password,
            username: validator.username,
          },
          body: {
            details: previous_snapshot.details,
            xid: snapshot.xid,
          },
        }).and_return(http_response body: expected_response.to_json)

      response = client.assignment_snapshot snapshot, previous_snapshot

      expect(response).to eq(expected_response)
    end

    context "when no previous adapter snapshot is passed in" do
      it "sends a post message to the validator client" do
        expect(ExternalAdapterClient).to receive(:post)
          .with("#{validator.url}/subtasks/#{subtask.xid}/snapshots", {
            basic_auth: {
              password: validator.password,
              username: validator.username,
            },
            body: {
              xid: snapshot.xid,
            },
          }).and_return(http_response body: expected_response.to_json)

        response = client.assignment_snapshot snapshot

        expect(response).to eq(expected_response)
      end
    end
  end

  describe "#stop_assignment" do
    let(:subtask) { factory_create :subtask }
    let(:expected_response) { hashie({a: 1}) }

    it "sends a post message to the validator client" do
      expect(ExternalAdapterClient).to receive(:delete)
        .with("#{validator.url}/subtasks/#{subtask.xid}", {
          basic_auth: {
            password: validator.password,
            username: validator.username,
          },
          body: {},
        }).and_return(http_response body: expected_response.to_json)

      response = client.stop_assignment subtask

      expect(response).to eq(expected_response)
    end
  end

end
