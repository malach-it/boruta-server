defmodule BorutaIdentity.IdentityProviders.Backend do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.Repo

  @type t :: %__MODULE__{
          type: String.t(),
          name: String.t(),
          is_default: boolean(),
          metadata_fields: map(),
          password_hashing_alg: String.t(),
          password_hashing_opts: map(),
          email_templates: Ecto.Association.NotLoaded.t() | list(EmailTemplate.t()),
          smtp_from: String.t() | nil,
          smtp_relay: String.t() | nil,
          smtp_username: String.t() | nil,
          smtp_password: String.t() | nil,
          smtp_tls: String.t() | nil,
          smtp_port: integer() | nil,
          ldap_pool_size: integer() | nil,
          ldap_host: String.t() | nil,
          ldap_user_rdn_attribute: String.t() | nil,
          ldap_base_dn: String.t() | nil,
          ldap_ou: String.t() | nil,
          ldap_master_dn: String.t() | nil,
          ldap_master_password: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @backend_types [Internal, Ldap]

  @smtp_tls_types [
    :always,
    :never,
    :if_available
  ]

  @password_hashing_modules %{
    "argon2" => Argon2,
    "bcrypt" => Bcrypt,
    "pbkdf2" => Pbkdf2
  }

  @password_hashing_opts_schema %{
    "argon2" => %{
      "type" => "object",
      "properties" => %{
        "salt_len" => %{"type" => "number"},
        "t_cost" => %{"type" => "number"},
        "m_cost" => %{"type" => "number"},
        "parallelism" => %{"type" => "number"},
        "format" => %{"type" => "string", "pattern" => "^(encoded|raw_hash|report)$"},
        "hashlen" => %{"type" => "number", "minimum" => 1, "maximum" => 128},
        "argon2_type" => %{"type" => "number", "minimum" => 0, "maximum" => 2}
      },
      "additionalProperties" => false
    },
    "bcrypt" => %{
      "type" => "object",
      "properties" => %{
        "log_rounds" => %{"type" => "number"},
        "legacy" => %{"type" => "boolean"}
      },
      "additionalProperties" => false
    },
    "pbkdf2" => %{
      "type" => "object",
      "properties" => %{
        "salt_len" => %{"type" => "number"},
        "format" => %{"type" => "string", "pattern" => "^(modular|django|hex)$"},
        "digest" => %{"type" => "string", "pattern" => "^(sha224|sha256|sha384|sha512)$"},
        "length" => %{"type" => "number", "minimum" => 1, "maximum" => 64}
      },
      "additionalProperties" => false
    }
  }

  @federated_server_schema %{
    "type" => "object",
    "properties" => %{
      "name" => %{"type" => "string"},
      "client_id" => %{"type" => "string"},
      "client_secret" => %{"type" => "string"},
      "base_url" => %{"type" => "string"},
      "authorize_path" => %{"type" => "string"},
      "token_path" => %{"type" => "string"}
    },
    "required" => ["name", "client_id", "client_secret", "base_url", "authorize_path", "token_path"],
    "additionalProperties" => false
  }

  @metadata_fields_schema ExJsonSchema.Schema.resolve(%{
                            "type" => "array",
                            "items" => %{
                              "type" => "object",
                              "properties" => %{
                                "attribute_name" => %{"type" => "string"},
                                "user_editable" => %{"type" => "boolean"},
                                "scopes" => %{"type" => "array", "items" => %{"type" => "string"}}
                              },
                              "required" => ["attribute_name"],
                              "additionalProperties" => false
                            }
                          })

  @spec backend_types() :: list(atom)
  def backend_types, do: @backend_types

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "backends" do
    field(:type, :string)
    field(:is_default, :boolean, default: false)
    field(:name, :string)
    field(:metadata_fields, {:array, :map}, default: [])

    # smtp config
    field(:smtp_from, :string)
    field(:smtp_relay, :string)
    field(:smtp_username, :string)
    field(:smtp_password, :string)
    field(:smtp_ssl, :boolean)
    field(:smtp_tls, :string)
    field(:smtp_port, :integer)

    # ldap config
    field(:ldap_pool_size, :integer, default: 5)
    field(:ldap_host, :string)
    field(:ldap_user_rdn_attribute, :string)
    field(:ldap_base_dn, :string)
    field(:ldap_ou, :string)
    field(:ldap_master_dn, :string)
    field(:ldap_master_password, :string)

    # internal config
    field(:password_hashing_alg, :string, default: "argon2")
    field(:password_hashing_opts, :map, default: %{})

    # identity federation
    field(:federated_servers, {:array, :map}, default: [])

    has_many(:email_templates, EmailTemplate)

    timestamps()
  end

  @spec default!() :: t()
  def default! do
    Repo.get_by!(__MODULE__, is_default: true)
  end

  @spec implementation(t()) :: atom()
  def implementation(%__MODULE__{type: type}) do
    String.to_atom(type)
  end

  @spec features(backend :: t()) :: list(atom())
  def features(backend) do
    apply(implementation(backend), :features, [])
  end

  @spec password_hashing_module(t()) :: atom()
  def password_hashing_module(%__MODULE__{password_hashing_alg: password_hashing_alg}) do
    @password_hashing_modules[password_hashing_alg]
  end

  @spec password_hashing_opts(t()) :: Keyword.t()
  def password_hashing_opts(%__MODULE__{password_hashing_opts: password_hashing_opts}) do
    Enum.map(password_hashing_opts, fn
      {key, value} when is_binary(value) -> {String.to_atom(key), String.to_atom(value)}
      {key, value} -> {String.to_atom(key), value}
    end)
    |> Enum.into([])
  end

  @spec email_template(backend :: t(), type :: atom()) :: EmailTemplate.t() | nil
  def email_template(%__MODULE__{email_templates: email_templates} = backend, type)
      when is_list(email_templates) do
    case Enum.find(email_templates, fn
           %EmailTemplate{type: template_type} -> Atom.to_string(type) == template_type
         end) do
      nil ->
        template = EmailTemplate.default_template(type)

        template &&
          %{
            template
            | backend_id: backend.id,
              backend: backend
          }

      template ->
        %{template | backend: backend}
    end
  end

  @doc false
  def changeset(backend, attrs) do
    backend
    |> cast(attrs, [
      :type,
      :name,
      :is_default,
      :metadata_fields,
      :password_hashing_alg,
      :password_hashing_opts,
      :ldap_pool_size,
      :ldap_host,
      :ldap_user_rdn_attribute,
      :ldap_base_dn,
      :ldap_ou,
      :ldap_master_dn,
      :ldap_master_password,
      :smtp_from,
      :smtp_relay,
      :smtp_username,
      :smtp_password,
      :smtp_ssl,
      :smtp_tls,
      :smtp_port,
      :federated_servers
    ])
    |> validate_required([:name, :password_hashing_alg])
    |> validate_metadata_fields()
    |> validate_federated_servers()
    |> validate_inclusion(:type, Enum.map(@backend_types, &Atom.to_string/1))
    |> validate_inclusion(:smtp_tls, Enum.map(@smtp_tls_types, &Atom.to_string/1))
    |> foreign_key_constraint(:identity_provider, name: :identity_providers_backend_id_fkey)
    |> set_default()
    |> validate_backend_by_type()
  end

  @doc false
  def delete_changeset(%__MODULE__{id: backend_id} = backend) do
    case default!().id == backend_id do
      true ->
        change(backend)
        |> add_error(:is_default, "Deleting a default backend is prohibited.")

      false ->
        change(backend)
    end
    |> foreign_key_constraint(:identity_provider,
      name: :identity_providers_backend_id_fkey,
      message: "This backend is linked to an identity provider. Please unlink it before continue."
    )
    |> foreign_key_constraint(:user,
      name: :users_backend_id_fkey,
      message: "This backend has existing users. Please delete them before continue"
    )
  end

  defp validate_metadata_fields(
         %Ecto.Changeset{changes: %{metadata_fields: metadata_fields}} = changeset
       ) do
    case ExJsonSchema.Validator.validate(@metadata_fields_schema, metadata_fields) do
      :ok ->
        changeset

      {:error, errors} ->
        Enum.reduce(errors, changeset, fn {message, path}, changeset ->
          add_error(changeset, :metadata_fields, "#{message} at #{path}")
        end)
    end
  end

  defp validate_metadata_fields(changeset), do: changeset

  defp validate_federated_servers(
         %Ecto.Changeset{changes: %{federated_servers: federated_servers}} = changeset
      ) do
    Enum.reduce(federated_servers, changeset, fn federated_server, changeset ->
      case ExJsonSchema.Validator.validate(@federated_server_schema, federated_server) do
        :ok ->
          changeset

        {:error, errors} ->
          Enum.reduce(errors, changeset, fn {message, path}, changeset ->
            add_error(changeset, :federated_servers, "#{message} at #{path}")
          end)
      end
    end)
  end

  defp validate_federated_servers(changeset), do: changeset

  defp set_default(%Ecto.Changeset{changes: %{is_default: false}} = changeset) do
    Ecto.Changeset.add_error(
      changeset,
      :is_default,
      "There must be at least one default backend."
    )
  end

  defp set_default(%Ecto.Changeset{changes: %{is_default: _is_default}} = changeset) do
    # TODO use a transaction to change default backend
    case Ecto.Changeset.change(default!(), %{is_default: false}) |> Repo.update() do
      {:ok, _backend} ->
        changeset

      {:error, changeset} ->
        Ecto.Changeset.add_error(
          changeset,
          :is_default,
          "Cannot remove value from the existing default backend."
        )
    end
  rescue
    Ecto.NoResultsError -> changeset
  end

  defp set_default(changeset), do: changeset

  defp validate_backend_by_type(changeset) do
    type = get_field(changeset, :type)

    validate_backend(changeset, String.to_atom(type))
  end

  defp validate_backend(changeset, Internal) do
    changeset
    |> validate_inclusion(:password_hashing_alg, Map.keys(@password_hashing_modules))
    |> validate_password_hashing_opts()
  end

  defp validate_backend(changeset, Ldap) do
    changeset
    |> validate_required([
      :ldap_pool_size,
      :ldap_host,
      :ldap_user_rdn_attribute,
      :ldap_base_dn
    ])
    |> validate_inclusion(:ldap_pool_size, 1..50)
  end

  defp validate_backend(changeset, _implementation), do: changeset

  defp validate_password_hashing_opts(changeset) do
    alg = fetch_field!(changeset, :password_hashing_alg)
    opts = fetch_field!(changeset, :password_hashing_opts)

    case ExJsonSchema.Validator.validate(@password_hashing_opts_schema[alg], opts) do
      :ok ->
        changeset

      {:error, errors} ->
        Enum.reduce(errors, changeset, fn {message, path}, changeset ->
          add_error(changeset, :password_hashing_opts, "#{message} at #{path}")
        end)
    end
  end
end
