defmodule BorutaAdmin.ConfigurationLoader do
  @moduledoc false

  alias Boruta.Ecto.Admin
  alias BorutaAdmin.Clients
  alias BorutaAdmin.ConfigurationLoader.Schema
  alias BorutaGateway.Upstreams
  alias BorutaIdentity.Configuration
  alias BorutaIdentity.Configuration.ErrorTemplate
  alias BorutaIdentity.IdentityProviders
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
    load_configuration(configuration, %{})
  end

  def load_configuration(%{"gateway" => gateway_configurations} = configuration, result) when is_list(gateway_configurations) do
    result =
      Map.put(
        result,
        :gateway,
        Enum.map(gateway_configurations, fn gateway_configuration ->
          with :ok <-
                 ExJsonSchema.Validator.validate(Schema.gateway(), gateway_configuration,
                   error_formatter: BorutaFormatter
                 ),
               {:ok, upstream} <- Upstreams.create_upstream(gateway_configuration) do
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

  def load_configuration(%{"microgateway" => gateway_configurations} = configuration, result) when is_list(gateway_configurations) do
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
                 Upstreams.create_upstream(gateway_configuration) do
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

  def load_configuration(%{"organization" => organization_configurations} = configuration, result) when is_list(organization_configurations) do
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
                 BorutaIdentity.Admin.create_organization(organization_configuration) do
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

  def load_configuration(%{"backend" => backend_configurations} = configuration, result) when is_list(backend_configurations) do
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
                 IdentityProviders.create_backend(backend_configuration) do
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
      ) when is_list(identity_provider_configurations) do
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
                 IdentityProviders.create_identity_provider(identity_provider_configuration) do
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

  def load_configuration(%{"client" => client_configurations} = configuration, result) when is_list(client_configurations) do
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
                 Clients.create_client(client_configuration) do
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

  def load_configuration(%{"scope" => scope_configurations} = configuration, result) when is_list(scope_configurations) do
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
                 Admin.create_scope(scope_configuration) do
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

  def load_configuration(%{"role" => role_configurations} = configuration, result) when is_list(role_configurations) do
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
                 BorutaIdentity.Admin.create_role(role_configuration) do
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
      ) when is_list(error_template_configurations) do
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
end
