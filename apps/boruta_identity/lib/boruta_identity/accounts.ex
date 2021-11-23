defmodule BorutaIdentity.Accounts do
  @moduledoc """
  The Accounts context.
  """

  alias BorutaIdentity.Accounts.Confirmations
  alias BorutaIdentity.Accounts.Consents
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.Registrations
  alias BorutaIdentity.Accounts.Sessions
  alias BorutaIdentity.Accounts.Users

  ## Database getters

  defdelegate list_users, to: Users
  defdelegate get_user(id), to: Users
  defdelegate get_user_by_email(email), to: Users
  defdelegate check_user_password(user, password), to: Users
  defdelegate get_user_by_session_token(token), to: Users
  defdelegate get_user_by_reset_password_token(token), to: Users
  defdelegate get_user_scopes(user_id), to: Users

  ## User registration

  defdelegate register_user(attrs), to: Registrations
  defdelegate change_user_registration(user), to: Registrations
  defdelegate change_user_registration(user, attrs), to: Registrations
  defdelegate update_user_password(user, password, attrs), to: Registrations
  defdelegate change_user_password(user), to: Registrations
  defdelegate change_user_password(user, attrs), to: Registrations
  defdelegate reset_user_password(user, attrs), to: Registrations
  defdelegate update_user_authorized_scopes(user, scopes), to: Registrations
  defdelegate change_user_email(user), to: Registrations
  defdelegate change_user_email(user, attrs), to: Registrations
  defdelegate apply_user_email(user, password, attrs), to: Registrations
  defdelegate update_user_email(user, token), to: Registrations
  defdelegate delete_user(id), to: Registrations

  ## Delivery

  defdelegate deliver_update_email_instructions(user, current_email, update_email_url_fun),
    to: Deliveries
  defdelegate deliver_user_confirmation_instructions(user, confirmation_url_fun), to: Deliveries
  defdelegate deliver_user_reset_password_instructions(user, reset_password_url_fun), to: Deliveries

  ## Session

  defdelegate generate_user_session_token(user), to: Sessions
  defdelegate delete_session_token(token), to: Sessions

  ## Confirmation

  defdelegate confirm_user(token), to: Confirmations

  ## Consent
  defdelegate consent(user, attrs), to: Consents
  defdelegate consented?(user, conn), to: Consents
  defdelegate consented_scopes(user, conn), to: Consents
end
