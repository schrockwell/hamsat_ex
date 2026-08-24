defmodule Hamsat.Push.WebPush do
  @moduledoc """
  Sends Web Push notifications with an encrypted payload (RFC 8291 "aesgcm"
  scheme with VAPID authorization).

  Adapted from the MIT-licensed `web_push_elixir` package, using HTTPoison for
  delivery and app config for the VAPID keys:

      config :hamsat, :vapid,
        subject: "mailto:...",
        public_key: "<base64url>",
        private_key: "<base64url>"

  Generate a keypair with `Hamsat.Push.WebPush.generate_vapid_keys/0`.
  """

  @doc """
  Sends a push notification to one subscription.

  `subscription` is a map with `"endpoint"` and `"keys" => %{"p256dh", "auth"}`
  (the JSON a browser's `PushSubscription` serializes to). Returns `{:ok, status}`,
  `{:error, :expired}` when the subscription is gone (HTTP 404/410), or
  `{:error, term}`.
  """
  def send_notification(%{"endpoint" => endpoint, "keys" => %{"p256dh" => p256dh, "auth" => auth}}, message) do
    vapid = Application.fetch_env!(:hamsat, :vapid)
    vapid_public_key = url_decode(Keyword.fetch!(vapid, :public_key))
    vapid_private_key = url_decode(Keyword.fetch!(vapid, :private_key))

    encrypted = encrypt_payload(message, p256dh, auth)
    jwt = sign_json_web_token(endpoint, vapid_public_key, vapid_private_key, Keyword.fetch!(vapid, :subject))

    headers = [
      {"authorization", "WebPush #{jwt}"},
      {"content-encoding", "aesgcm"},
      {"content-type", "application/octet-stream"},
      {"crypto-key", "dh=#{url_encode(encrypted.local_public_key)};p256ecdsa=#{url_encode(vapid_public_key)}"},
      {"encryption", "salt=#{url_encode(encrypted.salt)}"},
      {"ttl", "60"},
      {"urgency", "high"}
    ]

    case HTTPoison.post(endpoint, encrypted.ciphertext, headers, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: status}} when status in 200..202 ->
        {:ok, status}

      {:ok, %HTTPoison.Response{status_code: status}} when status in [404, 410] ->
        {:error, :expired}

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Generates a VAPID keypair as base64url-encoded strings."
  def generate_vapid_keys do
    {public, private} = :crypto.generate_key(:ecdh, :prime256v1)
    %{public_key: url_encode(public), private_key: url_encode(private)}
  end

  @doc "The configured VAPID public key, as the client-side applicationServerKey."
  def vapid_public_key do
    :hamsat |> Application.fetch_env!(:vapid) |> Keyword.fetch!(:public_key)
  end

  defp url_encode(binary), do: Base.url_encode64(binary, padding: false)
  defp url_decode(string), do: Base.url_decode64!(string, padding: false)

  defp hkdf(salt, initial_keying_material, info, length) do
    pseudo_random_key =
      :crypto.mac_init(:hmac, :sha256, salt)
      |> :crypto.mac_update(initial_keying_material)
      |> :crypto.mac_final()

    :crypto.mac_init(:hmac, :sha256, pseudo_random_key)
    |> :crypto.mac_update(info)
    |> :crypto.mac_update(<<1>>)
    |> :crypto.mac_final()
    |> :binary.part(0, length)
  end

  defp encrypt_payload(message, p256dh, auth) do
    client_public_key = url_decode(p256dh)
    client_auth_secret = url_decode(auth)

    salt = :crypto.strong_rand_bytes(16)
    {local_public_key, local_private_key} = :crypto.generate_key(:ecdh, :prime256v1)
    shared_secret = :crypto.compute_key(:ecdh, client_public_key, local_private_key, :prime256v1)

    pseudo_random_key = hkdf(client_auth_secret, shared_secret, "Content-Encoding: auth" <> <<0>>, 32)

    context =
      <<0, byte_size(client_public_key)::unsigned-big-integer-size(16)>> <>
        client_public_key <>
        <<byte_size(local_public_key)::unsigned-big-integer-size(16)>> <> local_public_key

    content_encryption_key =
      hkdf(salt, pseudo_random_key, "Content-Encoding: aesgcm" <> <<0>> <> "P-256" <> context, 16)

    nonce = hkdf(salt, pseudo_random_key, "Content-Encoding: nonce" <> <<0>> <> "P-256" <> context, 12)

    padded_message = <<0::unsigned-big-integer-size(16)>> <> message

    {cipher_text, cipher_tag} =
      :crypto.crypto_one_time_aead(:aes_128_gcm, content_encryption_key, nonce, padded_message, <<>>, true)

    %{ciphertext: cipher_text <> cipher_tag, salt: salt, local_public_key: local_public_key}
  end

  defp sign_json_web_token(endpoint, vapid_public_key, vapid_private_key, subject) do
    uri = URI.parse(endpoint)

    json_web_token =
      JOSE.JWT.from_map(%{
        aud: uri.scheme <> "://" <> uri.host,
        exp: DateTime.to_unix(DateTime.utc_now()) + 12 * 3600,
        sub: subject
      })

    json_web_key =
      JOSE.JWK.from_key(
        {:ECPrivateKey, 1, vapid_private_key, {:namedCurve, {1, 2, 840, 10045, 3, 1, 7}}, vapid_public_key, nil}
      )

    {%{alg: :jose_jws_alg_ecdsa}, signed_json_web_token} =
      JOSE.JWS.compact(JOSE.JWT.sign(json_web_key, %{"alg" => "ES256"}, json_web_token))

    signed_json_web_token
  end
end
