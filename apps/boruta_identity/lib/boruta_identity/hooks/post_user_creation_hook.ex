defmodule BorutaIdentity.PostUserCreationHook do
  @moduledoc false

  use Decorator.Define, post_user_creation_hook: 1

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Admin
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Organizations

  def post_user_creation_hook(_options, body, _context) do
    quote do
      with {:ok, user} = result <- unquote(body),
           {:ok, user} <- BorutaIdentity.PostUserCreationHook.maybe_create_organization(user) do
        {:ok, user}
      end
    end
  end

  @spec maybe_create_organization(user :: User.t()) ::
          {:ok, user :: User.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def maybe_create_organization(
        %User{backend: %Backend{create_default_organization: true}} = user
      ) do
    with {:ok, organization} <-
           Organizations.create_organization(%{
             name: "default_#{user.uid}",
             label: "Default"
           }) do
      organizations =
        [organization | user.organizations]
        |> Enum.map(fn %{id: id} -> %{"id" => id} end)

      Admin.update_user_organizations(user, organizations)
    end
  end

  def maybe_create_organization(user), do: {:ok, user}
end
