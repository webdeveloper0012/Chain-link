class EthereumOracle < ActiveRecord::Base
  SCHEMA_NAME = 'ethereumBytes32JSON'

  include AdapterBase

  has_one :account, through: :ethereum_contract
  has_one :subtask, as: :adapter
  has_one :assignment, through: :subtask
  has_one :ethereum_contract, as: :owner
  has_one :template, through: :ethereum_contract
  has_one :term, as: :expectation
  has_many :writes, class_name: 'EthereumOracleWrite', as: :oracle

  validates :endpoint, format: { with: /\A#{CustomExpectation::URL_REGEXP}\z/x }
  validates :ethereum_contract, presence: true
  validates :fields, presence: true

  before_validation :set_up_from_body, on: :create


  def fields=(fields)
    self.field_list = Array.wrap(fields).to_json if fields.present?
    self.fields
  end

  def fields
    return [] if field_list.blank?
    JSON.parse(field_list)
  end

  def current_value
    return @current_value if @current_value.present?
    endpoint_response = HttpRetriever.get(endpoint)
    @current_value = JsonTraverser.parse(endpoint_response, fields).to_s[0..31]
  end

  def assignment_type
    'ethereum'
  end

  def related_term
    term || assignment.term
  end

  def get_status(_assignment_snapshot, _previous_snapshot = nil)
    write = updater.perform format_hex_value(current_value), current_value
    write.snapshot_decorator
  end

  def schema_errors_for(parameters)
    []
  end

  def contract_address
    ethereum_contract.address
  end

  def contract_write_address
    ethereum_contract.write_address
  end

  def ready?
    ethereum_contract.try(:address).present?
  end

  def contract_confirmed(address)
    subtask.mark_ready if address.present?
  end

  def initialization_details
    {
      address: ethereum_contract.address,
      jsonABI: template.json_abi,
      readAddress: template.read_address,
      writeAddress: template.write_address,
      solidityABI: template.solidity_abi,
    }
  end


  private

  def set_up_from_body
    return unless body.present?

    self.endpoint = body['endpoint']
    self.fields = body['fields']
    build_ethereum_contract adapter_type: SCHEMA_NAME
  end

  def updater
    Ethereum::OracleUpdater.new(self)
  end

  def format_hex_value(value)
    Ethereum::Client.new.format_bytes32_hex value
  end

end
