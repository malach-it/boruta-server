defmodule BorutaIdentity.Accounts.UserNotifier do
  @moduledoc false

  require Logger

  import Swoosh.Email

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.IdentityProviders.Backend

  def smtp_adapter do
    Application.get_env(:boruta_identity, BorutaIdentity.SMTP)[:adapter]
  end

  # TODO hide Swoosh from the rest of the world
  @spec deliver(email :: %Swoosh.Email{}, backend :: Backend.t()) ::
          {:ok, email :: %Swoosh.Email{}} | {:error, reason :: String.t()}
  def deliver(email, backend) do
    config = [
      relay: backend.smtp_relay,
      username: backend.smtp_username,
      password: backend.smtp_password,
      ssl: false,
      tls: String.to_atom(backend.smtp_tls),
      auth: :always,
      port: backend.smtp_port,
      # dkim: [
      #   s: "default", d: "domain.com",
      #   private_key: {:pem_plain, File.read!("priv/keys/domain.private")}
      # ],
      retries: 2,
      no_mx_lookups: false
    ]

    with :ok <- smtp_adapter().validate_config(config),
         {:ok, _} <- smtp_adapter().deliver(email, config) do
      {:ok, email}
    else
      {:error, {_status, %{"Errors" => errors}}} ->
        reason =
          errors
          |> Enum.map_join(", ", fn %{"ErrorMessage" => message} -> message end)

        {:error, reason}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    _error ->
      {:error, "Bad SMTP configuration."}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(backend, user, url) do
    template = Enum.find(backend.email_templates, fn %EmailTemplate{type: type} ->
      type == "confirmation_instructions"
    end) || EmailTemplate.default_template(:confirmation_instructions)

    context = %{
      user: Map.from_struct(user),
      url: url
    }

    text_body = Mustachex.render(template.txt_content, context)
    html_body = Mustachex.render(template.html_content, context)

    new()
    |> from(user.backend.smtp_from)
    |> to(user.username)
    |> subject("Confirm your account.")
    |> text_body(text_body)
    |> html_body(html_body)
  rescue
    _error ->
      {:error, "Bad SMTP configuration."}
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(backend, user, url) do
    template = Enum.find(backend.email_templates, fn %EmailTemplate{type: type} ->
      type == "reset_password_instructions"
    end) || EmailTemplate.default_template(:reset_password_instructions)

    context = %{
      user: Map.from_struct(user),
      url: url
    }

    text_body = Mustachex.render(template.txt_content, context)
    html_body = Mustachex.render(template.html_content, context)

    new()
    |> from(user.backend.smtp_from)
    |> to(user.username)
    |> subject("Reset your password.")
    |> text_body(text_body)
    |> html_body(html_body)
  rescue
    _error ->
      {:error, "Bad SMTP configuration."}
  end
end
