defmodule TelemetryUI.Web.Crypto do
  @moduledoc false

  # Use AES 128 Bit Keys for Encryption.
  @block_size 16

  def encrypt(plaintext, key) do
    key = normalize_key(key)
    iv = :crypto.strong_rand_bytes(@block_size)
    plaintext = pad(plaintext, @block_size)

    encrypted_text = :crypto.crypto_one_time(:aes_128_cbc, key, iv, plaintext, true)
    encrypted_text = iv <> encrypted_text
    :base64.encode(encrypted_text)
  end

  def decrypt(ciphertext, key) do
    key = normalize_key(key)
    ciphertext = :base64.decode(ciphertext)
    <<iv::binary-@block_size, ciphertext::binary>> = ciphertext
    decrypted_text = :crypto.crypto_one_time(:aes_128_cbc, key, iv, ciphertext, false)
    unpad(decrypted_text)
  catch
    _, _ -> nil
  end

  defp normalize_key(key) do
    pad(binary_slice(pad(key, @block_size), 1..@block_size), @block_size)
  end

  defp unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end

  # PKCS5Padding
  defp pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<to_add>>, to_add)
  end
end
