require 'openssl'
require 'hkdf'

module AliquotPay
  class Util
    def self.generate_ephemeral_key
      OpenSSL::PKey::EC.new(AliquotPay::EC_CURVE).generate_key
    end

    def self.generate_shared_secret(private_key, public_key)
      private_key.dh_compute_key(public_key)
    end

    def self.derive_keys(ephemeral_public_key, shared_secret, info, length: 32)
      input_keying_material = ephemeral_public_key + shared_secret
      if OpenSSL.const_defined?(:KDF) && OpenSSL::KDF.respond_to?(:hkdf)
        h = OpenSSL::Digest::SHA256.new
        hbytes = OpenSSL::KDF.hkdf(input_keying_material, hash: h, salt: '', length: length * 2, info: info)
      else
        hbytes = HKDF.new(input_keying_material, algorithm: 'SHA256', info: info).next_bytes(length * 2)
      end

      {
        aes_key: hbytes[0..length - 1],
        mac_key: hbytes[length..2 * length],
      }
    end

    def self.calculate_tag(mac_key, encrypted_message)
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::HMAC.digest(digest, mac_key, encrypted_message)
    end
  end
end
