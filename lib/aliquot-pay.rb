require 'base64'
require 'openssl'

require 'aliquot-pay/util'

module AliquotPay
  class Error < StandardError; end

  EC_CURVE = 'prime256v1'.freeze

  DEFAULTS = {
    info: 'Google',
  }.freeze

  def self.sign(key, encrypted_message)
    d = OpenSSL::Digest::SHA256.new
    def key.private?; private_key?; end
    Base64.strict_encode64(key.sign(d, encrypted_message))
  end

  def self.encrypt(cleartext_message, recipient, info = 'Google')
    eph = AliquotPay::Util.generate_ephemeral_key
    ss  = AliquotPay::Util.generate_shared_secret(eph, recipient.public_key)

    keys = AliquotPay::Util.derive_keys(eph.public_key.to_bn.to_s(2), ss, info)

    c = OpenSSL::Cipher::AES128.new(:CTR)
    c.encrypt
    c.key = keys[:aes_key]

    encrypted_message = c.update(cleartext_message) + c.final

    tag = AliquotPay::Util.calculate_tag(keys[:mac_key], encrypted_message)

    {
      encryptedMessage: Base64.strict_encode64(encrypted_message),
      ephemeralPublicKey: Base64.strict_encode64(eph.public_key.to_bn.to_s(2)),
      tag: Base64.strict_encode64(tag),
    }
  end

  # Return a default payment
  def self.payment(
    auth_method: :PAN_ONLY,
    expiration: ((Time.now.to_f + 60 * 5) * 1000).round.to_s
  )
    id = Base64.strict_encode64(OpenSSL::Random.random_bytes(24))
    p = {
      'messageExpiration' => expiration,
      'messageId' => id,
      'paymentMethodDetails' => {
        'expirationYear' =>  2023,
        'expirationMonth' => 12,
        'pan' =>             '4111111111111111',
        'authMethod' =>      'PAN_ONLY',
      },
    }

    if auth_method == :CRYPTOGRAM_3DS
      p['paymentMethodDetails']['auth_method']  = 'CRYPTOGRAM_3DS'
      p['paymentMethodDetails']['cryptogram']   = 'SOME CRYPTOGRAM'
      p['paymentMethodDetails']['eciIndicator'] = '05'
    end

    p
  end

  # Return a string length as a 4byte little-endian integer, as a string
  def self.four_byte_length(str)
    [str.length].pack('V')
  end

  def self.signature_string(
    message,
    recipient_id = 'merchant:0123456789',
    sender_id = DEFAULTS[:info],
    protocol_version = 'ECv1'
  )

    four_byte_length(sender_id) +
      sender_id +
      four_byte_length(recipient_id) +
      recipient_id +
      four_byte_length(protocol_version) +
      protocol_version +
      four_byte_length(message) +
      message
  end
end