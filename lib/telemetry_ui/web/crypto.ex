defmodule TelemetryUI.Web.Crypto do
  # Use AES 128 Bit Keys for Encryption.
  @block_size 16

  def encrypt(plaintext, key) do
    iv = :crypto.strong_rand_bytes(16)
    plaintext = pad(plaintext, @block_size)
    encrypted_text = :crypto.crypto_one_time(:aes_128_cbc, key, iv, plaintext, true)
    encrypted_text = iv <> encrypted_text
    :base64.encode(encrypted_text)
  catch
    _, _ -> nil
  end

  def decrypt(ciphertext, key) do
    ciphertext = :base64.decode(ciphertext)
    <<iv::binary-16, ciphertext::binary>> = ciphertext
    decrypted_text = :crypto.crypto_one_time(:aes_128_cbc, key, iv, ciphertext, false)
    unpad(decrypted_text)
  catch
    _, _ -> nil
  end

  def unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end

  # PKCS5Padding
  def pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<to_add>>, to_add)
  end
end
