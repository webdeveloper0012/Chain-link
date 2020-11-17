require 'ethereum'

module Ethereum
  class FormattedOracle < OracleBase

    SCHEMA_NAME = 'ethereumFormatted'

    validates :address, format: { with: /\A0x[0-9a-f]{40}\z/i }
    validates :update_address, format: { with: /\A(?:0x)?[0-9a-f]*\z/i }

    def get_status(assignment_snapshot, previous_snapshot = nil)
      value = previous_snapshot.try(:value) || config_value
      if valid_hex? value
        write = updater.perform value, value, payment_amount
        write.snapshot_decorator
      else
        raise InvalidHexValue.new(value)
      end
    end

    def ready?
      true
    end


    private

    def set_up_from_body
      if body.present?
        self.address = body['address'] || body['contractAddress']
        self.update_address = body['functionID'] || body['updateAddress'] || body['method']
        self.config_value = body['data'] || body['payload']
        self.payment_amount = (body['paymentAmount'] || body['amount']).to_i
      end
      self.ethereum_account = owner
    end

    def valid_hex?(value)
      value.to_s.match(/\A(?:0x)?[0-9a-f]*\z/i).present?
    end

  end

  class InvalidHexValue < StandardError
    def initialize(value)
      super "\"#{value}\" provided by the previous snapshot is not a valid hex value."
    end
  end
end
