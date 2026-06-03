defmodule BorutaAdmin.ConfigurationLoader do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Client
  alias Boruta.Ecto.Scope
  alias BorutaAdmin.ConfigurationLoader.Schema
  alias BorutaAuth.Repo, as: BorutaAuthRepo
  alias BorutaGateway.Repo, as: BorutaGatewayRepo
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream
  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.Clients
  alias BorutaIdentity.Configuration
  alias BorutaIdentity.Configuration.ErrorTemplate
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.Organizations.Organization
  alias BorutaIdentity.Repo, as: BorutaIdentityRepo
  alias ExJsonSchema.Validator.Error.BorutaFormatter

  @spec node_name() :: node_name :: String.t()
  def node_name do
    case Application.get_env(__MODULE__, :node_name) do
      nil ->
        path = Application.get_env(:boruta_admin, :configuration_path)

        %{
          "configuration" => %{
            "node_name" => node_name
          }
        } = YamlElixir.read_from_file!(path)

        Application.put_env(__MODULE__, :node_name, node_name)
        node_name

      node_name ->
        node_name
    end
  rescue
    _ ->
      node_name = Atom.to_string(node())
      Application.put_env(__MODULE__, :node_name, node_name)
      node_name
  end

  @spec aliases() :: aliases :: list(String.t())
  def aliases do
    case Application.get_env(__MODULE__, :aliases) do
      nil ->
        path = Application.get_env(:boruta_admin, :configuration_path)

        %{
          "configuration" => configuration
        } = YamlElixir.read_from_file!(path)

        aliases = Map.get(configuration, "aliases", []) |> with_default_aliases()
        Application.put_env(__MODULE__, :aliases, aliases)
        aliases

      aliases ->
        with_default_aliases(aliases)
    end
  rescue
    _ ->
      aliases = with_default_aliases([])
      Application.put_env(__MODULE__, :aliases, aliases)
      aliases
  end

  @spec from_file!(configuration_file_path :: String.t()) ::
          {:ok, result :: map()} | {:error, reason :: String.t()}
  def from_file!(path) do
    case YamlElixir.read_from_file!(path) do
      %{"configuration" => configuration, "version" => "1.0"} ->
        {:ok, load_configuration(configuration)}

      _ ->
        {:error, "Bad configuration file."}
    end
  end

  def load_configuration(configuration) do
    case Map.fetch(configuration, "aliases") do
      {:ok, aliases} -> Application.put_env(__MODULE__, :aliases, with_default_aliases(aliases))
      :error -> Application.put_env(__MODULE__, :aliases, with_default_aliases([]))
    end

    load_configuration(configuration, %{})
  end

  defp with_default_aliases(aliases) do
    aliases
    |> Kernel.++([node_hostname()])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp node_hostname do
    node()
    |> Atom.to_string()
    |> String.split("@", parts: 2)
    |> case do
      [_name, host] ->
        host

      [_name] ->
        case :inet.gethostname() do
          {:ok, hostname} -> to_string(hostname)
          {:error, _reason} -> nil
        end
    end
  end

  def load_configuration(%{"gateway" => gateway_configurations} = configuration, result)
      when is_list(gateway_configurations) do
    result =
      Map.put(
        result,
        :gateway,
        Enum.map(gateway_configurations, fn gateway_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(Schema.gateway(), gateway_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, upstream} <- upsert_upstream(gateway_configuration) do
            {:ok, upstream}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _upstream} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "gateway"), result)
  end

  def load_configuration(%{"microgateway" => gateway_configurations} = configuration, result)
      when is_list(gateway_configurations) do
    result =
      Map.put(
        result,
        :microgateway,
        Enum.map(gateway_configurations, fn gateway_configuration ->
          gateway_configuration =
            Map.put(
              gateway_configuration,
              "node_name",
              node_name()
            )

          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.microgateway(),
                   gateway_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, upstream} <-
                 upsert_upstream(gateway_configuration) do
            {:ok, upstream}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _upstream} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "microgateway"), result)
  end

  def load_configuration(%{"organization" => organization_configurations} = configuration, result)
      when is_list(organization_configurations) do
    result =
      Map.put(
        result,
        :organization,
        Enum.map(organization_configurations, fn organization_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.organization(),
                   organization_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, organization} <-
                 upsert_organization(organization_configuration) do
            {:ok, organization}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _organization} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "organization"), result)
  end

  def load_configuration(%{"backend" => backend_configurations} = configuration, result)
      when is_list(backend_configurations) do
    result =
      Map.put(
        result,
        :backend,
        Enum.map(backend_configurations, fn backend_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.backend(),
                   backend_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, backend} <-
                 upsert_backend(backend_configuration) do
            {:ok, backend}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _backend} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "backend"), result)
  end

  def load_configuration(
        %{"identity_provider" => identity_provider_configurations} = configuration,
        result
      )
      when is_list(identity_provider_configurations) do
    result =
      Map.put(
        result,
        :identity_provider,
        Enum.map(identity_provider_configurations, fn identity_provider_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.identity_provider(),
                   identity_provider_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, identity_provider} <-
                 upsert_identity_provider(identity_provider_configuration) do
            {:ok, identity_provider}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _identity_provider} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "identity_provider"), result)
  end

  def load_configuration(%{"client" => client_configurations} = configuration, result)
      when is_list(client_configurations) do
    result =
      Map.put(
        result,
        :client,
        Enum.map(client_configurations, fn client_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.client(),
                   client_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, client} <-
                 upsert_client(client_configuration) do
            {:ok, client}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _client} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "client"), result)
  end

  def load_configuration(%{"scope" => scope_configurations} = configuration, result)
      when is_list(scope_configurations) do
    result =
      Map.put(
        result,
        :scope,
        Enum.map(scope_configurations, fn scope_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.scope(),
                   scope_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, scope} <-
                 upsert_scope(scope_configuration) do
            {:ok, scope}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _scope} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "scope"), result)
  end

  def load_configuration(%{"role" => role_configurations} = configuration, result)
      when is_list(role_configurations) do
    result =
      Map.put(
        result,
        :role,
        Enum.map(role_configurations, fn role_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.role(),
                   role_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, role} <-
                 upsert_role(role_configuration) do
            {:ok, role}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _role} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "role"), result)
  end

  def load_configuration(
        %{"error_template" => error_template_configurations} = configuration,
        result
      )
      when is_list(error_template_configurations) do
    result =
      Map.put(
        result,
        :error_template,
        Enum.map(error_template_configurations, fn error_template_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(
                   Schema.error_template(),
                   error_template_configuration,
                   error_formatter: BorutaFormatter
                 ),
               template <-
                 Configuration.get_error_template!(
                   String.to_integer(error_template_configuration["type"])
                 ),
               {:ok, %ErrorTemplate{} = template} <-
                 Configuration.upsert_error_template(template, error_template_configuration) do
            {:ok, template}
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, [changeset]}

            {:error, errors} ->
              {:error, errors}
          end
        end)
        |> Enum.flat_map(fn
          {:ok, _error_template} -> []
          {:error, errors} -> errors
        end)
      )

    load_configuration(Map.delete(configuration, "error_template"), result)
  rescue
    _e in Ecto.NoResultsError ->
      result =
        Map.put(
          result,
          :error_template,
          ["Error template does not exist."]
        )

      load_configuration(Map.delete(configuration, "error_template"), result)
  end

  def load_configuration(%{}, result), do: result

  defp upsert_upstream(attrs) do
    case get_upstream(attrs) do
      nil -> Upstreams.create_upstream(attrs)
      %Upstream{} = upstream -> Upstreams.update_upstream(upstream, attrs)
    end
  end

  defp get_upstream(attrs) do
    node_name = Map.get(attrs, "node_name", "global")
    virtual_host = Map.get(attrs, "virtual_host")
    host = Map.get(attrs, "host")
    port = Map.get(attrs, "port")
    uris = Map.get(attrs, "uris", [])

    Upstream
    |> where(
      [upstream],
      upstream.node_name == ^node_name and upstream.host == ^host and upstream.port == ^port and
        upstream.uris == ^uris
    )
    |> where_virtual_host(virtual_host)
    |> BorutaGatewayRepo.one()
  end

  defp where_virtual_host(query, nil), do: where(query, [upstream], is_nil(upstream.virtual_host))

  defp where_virtual_host(query, virtual_host),
    do: where(query, [upstream], upstream.virtual_host == ^virtual_host)

  defp upsert_organization(attrs) do
    case get_by_id_or_name(BorutaIdentityRepo, Organization, attrs) do
      nil ->
        BorutaIdentity.Admin.create_organization(attrs)

      %Organization{} = organization ->
        BorutaIdentity.Admin.update_organization(organization, attrs)
    end
  end

  defp upsert_backend(attrs) do
    case get_by_id_or_name(BorutaIdentityRepo, Backend, attrs) do
      nil -> IdentityProviders.create_backend(attrs)
      %Backend{} = backend -> IdentityProviders.update_backend(backend, attrs)
    end
  end

  defp upsert_identity_provider(attrs) do
    case get_by_id_or_name(BorutaIdentityRepo, IdentityProvider, attrs) do
      nil ->
        IdentityProviders.create_identity_provider(attrs)

      %IdentityProvider{} = identity_provider ->
        IdentityProviders.update_identity_provider(identity_provider, attrs)
    end
  end

  defp upsert_client(attrs) do
    identity_provider_id = get_in(attrs, ["identity_provider", "id"])

    case get_by_id_or_name(BorutaAuthRepo, Client, attrs) do
      nil ->
        Clients.create_client(attrs)

      %Client{} = client ->
        BorutaAuthRepo.transaction(fn ->
          with {:ok, client} <- Admin.update_client(client, attrs),
               {:ok, client} <- Clients.insert_global_key_pair(client, attrs["key_pair_id"]),
               {:ok, _client_identity_provider} <-
                 IdentityProviders.upsert_client_identity_provider(
                   client.id,
                   identity_provider_id
                 ) do
            client
          else
            {:error, error} -> BorutaAuthRepo.rollback(error)
          end
        end)
    end
  end

  defp upsert_scope(attrs) do
    case get_scope(attrs) do
      nil -> Admin.create_scope(attrs)
      %Scope{} = scope -> Admin.update_scope(scope, attrs)
    end
  end

  defp get_scope(attrs) do
    get_by_id(BorutaAuthRepo, Scope, attrs) ||
      case Map.get(attrs, "name") do
        nil -> nil
        name -> BorutaAuthRepo.get_by(Scope, name: name)
      end
  end

  defp upsert_role(attrs) do
    case get_by_id_or_name(BorutaIdentityRepo, Role, attrs) do
      nil -> BorutaIdentity.Admin.create_role(attrs)
      %Role{} = role -> BorutaIdentity.Admin.update_role(role, attrs)
    end
  end

  defp get_by_id_or_name(repo, schema, attrs) do
    get_by_id(repo, schema, attrs) ||
      case Map.get(attrs, "name") do
        nil -> nil
        name -> repo.get_by(schema, name: name)
      end
  end

  defp get_by_id(repo, schema, attrs) do
    case Map.get(attrs, "id") do
      nil ->
        nil

      id ->
        case Ecto.UUID.cast(id) do
          {:ok, id} -> repo.get(schema, id)
          :error -> nil
        end
    end
  end
end
