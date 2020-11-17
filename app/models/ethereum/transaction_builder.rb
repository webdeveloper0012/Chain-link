class Ethereum::TransactionBuilder
  GAS_PRICE_TIP = ENV['ETHEREUM_GAS_PRICE_INCREASE'].to_i

  include BinaryAndHex
  include HasEthereumClient

  def initialize(account)
    @account = account
  end

  def perform(options)
    set_default options
    account.sign tx
    create_transaction_record
  end


  private

  attr_reader :account, :options

  def set_default(options)
    @options ||= {
      data: '',
      gas_price: adjusted_price(options[:gas_price]),
      gas_limit: 21_000,
      nonce: account.next_nonce,
      value: 0,
    }.merge(options)
  end

  def create_transaction_record
    account.ethereum_transactions.create({
      raw_hex: tx.hex,
      txid: ethereum.to_eth_hex(tx.hash)
    }.merge(options))
  end

  def tx
    @tx ||= Eth::Tx.new options.merge({
      data: hex_to_bin(options[:data]),
    })
  end

  def adjusted_price(price)
    price ||= ethereum.gas_price
    price + GAS_PRICE_TIP
  end

end
