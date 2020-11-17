class AdapterSnapshotHandler

  def initialize(snapshot)
    @snapshot = snapshot
    @adapter = snapshot.adapter
  end

  def perform(previous_snapshot)
    get_adapter_result(previous_snapshot)

    if response.present? && response.errors.blank?
      parse_adapter_response response
      snapshot.save
      assignment_snapshot.adapter_response(snapshot) if snapshot.fulfilled?
    elsif errors = response && response.errors
      Notification.delay.snapshot_failure assignment, errors
      assignment_snapshot.adapter_response snapshot
    else
      Notification.delay.snapshot_failure assignment, ["No response received."]
    end
  end


  private

  attr_reader :adapter, :response, :snapshot

  def get_adapter_result(previous_snapshot)
    @response ||= adapter.get_status(snapshot, previous_snapshot)
  end

  def parse_adapter_response(response)
    return unless response.fulfilled

    snapshot.fulfilled = true
    snapshot.description = response.description
    snapshot.description_url = response.description_url
    snapshot.details = response.details
    snapshot.status = response.status
    snapshot.summary ||= response.summary
    snapshot.value = response.value
  end

  def assignment
    snapshot.assignment
  end

  def assignment_snapshot
    snapshot.assignment_snapshot
  end

end
