class AssignmentsController < ExternalAdapterController

  skip_before_filter :set_adapter, only: [:create, :show]
  before_filter :set_coordinator, only: [:create, :show]
  before_filter :check_adapter_permissions, only: [:update]

  def create
    req = AssignmentRequest.new assignment_request_params

    if req.save
      success_response req
    else
      errors = req.errors.full_messages
      errors += req.assignment.errors.full_messages
      error_response errors
    end
  end

  def show
    assignment = coordinator.assignments.find_by(xid: params[:id])

    if assignment.present?
      success_response assignment
    else
      response_404 "Assignment not found"
    end
  end

  def update
    if assignment.update_status params[:status]
      success_response assignment
    else
      error_response assignment.errors.full_messages
    end
  end


  private

  def assignment
    return @assignment if @assignment.present?
    axid = (params[:xid] || params[:id])
    @assignment = adapter.assignments.find_by({
      xid: axid.gsub(/=.*/, '')
    }) if axid
  end

  def check_adapter_permissions
    response_404 'Assignment not found' if assignment.nil?
  end

  def assignment_request_params
    {
      body_json: params.except(:action, :controller).to_json,
      body_hash: params[:assignmentHash],
      coordinator: coordinator,
    }
  end

end
