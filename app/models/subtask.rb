class Subtask < ActiveRecord::Base

  belongs_to :adapter, polymorphic: true
  belongs_to :assignment, inverse_of: :subtasks
  has_many :adapter_snapshots
  has_many :snapshot_requests, inverse_of: :subtask

  validates :adapter, presence: true
  validates :assignment, presence: true
  validates :index, uniqueness: { scope: [:assignment] },
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parameters_against_schema

  before_validation :set_up, on: :create


  def parameters
    JSON.parse(adapter_params_json) if adapter_params_json.present?
  end

  def parameters=(params)
    self.adapter_params_json = params ? params.to_json : nil
    parameters
  end

  def end_at
    assignment.end_at
  end

  def mark_ready
    return if ready?
    assignment.subtask_ready(self) if update_attributes({
      ready: adapter.ready?
    })
  end

  def initialization_details
    adapter.initialization_details
  end

  def close_out!
    adapter.stop self
  end

  def snapshot_requested(request)
    assignment.check_status({
      request: request,
      requester: self,
    })
  end


  private

  def set_up
    return if assignment.blank? || adapter.blank?
    self.xid ||= SecureRandom.uuid
    start_response.errors.each do |error_message|
      errors.add(:base, "Adapter##{index} Error: #{error_message}")
    end if start_response.errors.present?
    self.ready = adapter.ready?
    true
  end

  def parameters_against_schema
    return unless parameters.present? && adapter.present?

    adapter.schema_errors_for(parameters).each do |error|
      errors.add(:base, error)
    end
  end

  def start_response
    @start_response ||= adapter.start self
  end

end
