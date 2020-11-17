class KeyPair < ActiveRecord::Base

  belongs_to :owner, polymorphic: true

  validates :private_key, presence: true
  validates :public_key, presence: true

  before_validation :generate_keys, on: :create

  scope :unowned, -> { where owner: nil }

  attr_accessor :use_uncompressed_pub


  def self.bitcoin_default
    find_by(public_key: ENV['BITCOIN_PUB_KEY']) ||
      unowned.order(:created_at).first
  end

  def self.key_for_tx(tx)
    public_keys = BitcoinClient.new.public_keys_for_tx(tx)
    where("public_key IN (?)", public_keys).first
  end


  def bitcoin_address
    return unless public_key.present?
    Bitcoin.pubkey_to_address(public_key)
  end

  def ethereum_address
    Ethereum::Client.hex(ethereum_key.to_address) if private_key.present?
  end

  def uncompressed_public_key
    ethereum_key.public_hex if private_key.present?
  end

  def bitcoin_key
    @bitcoin_key ||= Bitcoin.open_key(private_key)
  end

  def ethereum_key
    @ethereum_key ||= Eth::Key.new(priv: private_key)
  end

  def hex_key
    [bitcoin_key.public_key_hex].pack('H*')
  end

  def binary_public_key
    [public_key].pack('H*')
  end

  def btc_deposit_received(btc_outputs) #FIXME, just for development, key pairs shouldn't own addresses
    nil
  end

  def generate_keys
    key = generate_private_key

    self.private_key = key.priv
    if use_uncompressed_pub
      self.public_key = key.pub_uncompressed
    else
      self.public_key = key.pub_compressed
    end
  end

  def private_key
    if has_private_key?
      Eth::Key.decrypt(encrypted_private_key, password).private_hex
    end
  end

  def private_key=(decrypted)
    encrypted = Eth::Key.encrypt(decrypted, password)
    self.encrypted_private_key = encrypted
  end


  private

  def password
    ENV['PRIVATE_KEY_PASSWORD'].to_s
  end

  def has_private_key?
    encrypted_private_key.present?
  end

  def generate_private_key
    if has_private_key?
      ec_key = Bitcoin.open_key(private_key)
      compressed_pub = ec_key.public_key.to_hex.rjust(66, '0')
      Bitcoin::Key.new(ec_key.private_key.to_hex, compressed_pub)
    else
      Bitcoin::Key.generate
    end
  end

end
