admin_scope_definitions = [
  {"openid", "OpenID Connect capabilities"},
  {"email", "Email"},
  {"profile", "Profile"},
  {"scopes:manage:all", "Manage all scopes"},
  {"roles:manage:all", "Manage all roles"},
  {"clients:manage:all", "Manage all clients"},
  {"upstreams:manage:all", "Manage all upstreams"},
  {"users:manage:all", "Manage all users"},
  {"identity-providers:manage:all", "Manage all identity providers"},
  {"configuration:manage:all", "Manage all configuration"},
  {"logs:read:all", "Read all logs"},
  {"tokens:read:all", "Read all tokens"}
]

admin_scopes =
  Enum.map(admin_scope_definitions, fn {name, label} ->
    {:ok, scope} =
      BorutaAuth.Repo.insert(
        %Boruta.Ecto.Scope{name: name, label: label},
        on_conflict: :nothing
      )

    scope
  end)

{:ok, admin_role} =
  BorutaIdentity.Admin.create_role(%{
    name: "Boruta Administrator",
    scopes: admin_scopes
  })

codex_scope_definitions = [
  {"codex:event:userpromptsubmit", "Codex user prompt submission"},
  {"codex:event:pretooluse", "Codex pre tool use"},
  {"codex:event:permissionrequest", "Codex permission request"},
  {"codex:event:posttooluse", "Codex post tool use"},
  {"codex:event:stop", "Codex turn stop"},
  {"codex:prompt:submit", "Submit Codex prompts"},
  {"codex:permission:request", "Request Codex permissions"},
  {"codex:permission:escalated", "Use escalated Codex permissions"},
  {"codex:session:stop", "Stop Codex sessions"},
  {"codex:command:read", "Read Codex commands"},
  {"codex:command:write", "Write Codex commands"},
  {"codex:tool:use", "Use Codex tools"},
  {"codex:tool:read", "Use read-only Codex tools"},
  {"codex:tool:sensitive", "Use sensitive Codex tools"},
  {"codex:tool:result", "Receive Codex tool results"},
  {"codex:tool:bash", "Use Codex bash tool"},
  {"codex:tool:shell", "Use Codex shell tool"},
  {"codex:tool:exec-command", "Use Codex command execution tool"},
  {"codex:tool:functions-exec-command", "Use Codex command execution tool"},
  {"codex:tool:functions-write-stdin", "Use Codex process stdin tool"},
  {"codex:tool:functions-update-plan", "Use Codex plan update tool"},
  {"codex:tool:functions-request-user-input", "Use Codex user input request tool"},
  {"codex:tool:functions-list-mcp-resources", "List Codex MCP resources"},
  {"codex:tool:functions-list-mcp-resource-templates", "List Codex MCP resource templates"},
  {"codex:tool:functions-read-mcp-resource", "Read Codex MCP resources"},
  {"codex:tool:functions-view-image", "View local images through Codex"},
  {"codex:tool:functions-get-goal", "Read Codex goal state"},
  {"codex:tool:functions-create-goal", "Create Codex goals"},
  {"codex:tool:functions-update-goal", "Update Codex goals"},
  {"codex:tool:functions-apply-patch", "Use Codex patch tool"},
  {"codex:tool:write-stdin", "Use Codex process stdin tool"},
  {"codex:tool:apply-patch", "Use Codex patch tool"},
  {"codex:tool:imagegen", "Use Codex image generation tool"},
  {"codex:tool:image-gen-imagegen", "Use Codex image generation tool"},
  {"codex:tool:tool-search-tool", "Use Codex tool discovery"},
  {"codex:tool:multi-tool-use-parallel", "Use Codex parallel tool execution"},
  {"codex:tool:web-run", "Use Codex web tool"},
  {"codex:file:patch", "Patch files through Codex"},
  {"codex:image:generate", "Generate images through Codex"},
  {"codex:process:stdin", "Write to Codex process stdin"}
]

codex_scopes =
  Enum.map(codex_scope_definitions, fn {name, label} ->
    {:ok, scope} =
      BorutaAuth.Repo.insert(
        %Boruta.Ecto.Scope{name: name, label: label},
        on_conflict: :nothing
      )

    scope
  end)

{:ok, codex_role} =
  BorutaIdentity.Admin.create_role(%{
    name: "Codex agent",
    scopes: codex_scopes
  })

codex_scope_names = Enum.map(codex_scope_definitions, fn {name, _label} -> name end)

client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")

client =
  case Boruta.Ecto.Admin.create_client(%{
         name: "Boruta administration panel",
         secret: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET"),
         id: client_id,
         redirect_uris: [
           "#{System.get_env("BORUTA_ADMIN_BASE_URL", "http://localhost:4001")}/oauth-callback"
         ],
         access_token_ttl: 3600,
         authorization_code_ttl: 60,
         public_revoke: true
       }) do
    {:ok, client} -> client
    {:error, _error} -> Boruta.Ecto.Admin.get_client!(client_id)
  end

backend = BorutaIdentity.IdentityProviders.Backend.default!()

BorutaIdentity.IdentityProviders.create_identity_provider(%{
  name: "Default",
  registrable: true,
  backend_id: backend.id
})

identity_provider =
  case BorutaIdentity.IdentityProviders.create_identity_provider(%{
         name: "Boruta administration interface",
         registrable: false,
         backend_id: backend.id
       }) do
    {:ok, identity_provider} ->
      identity_provider

    {:error, _error} ->
      BorutaIdentity.IdentityProviders.list_identity_providers()
      |> Enum.find(fn %{name: name} -> name == "Boruta administration interface" end)
  end

BorutaIdentity.IdentityProviders.upsert_client_identity_provider(client.id, identity_provider.id)

email = System.get_env("BORUTA_ADMIN_EMAIL")

user =
  case BorutaIdentity.Accounts.Internal.User.registration_changeset(
         %BorutaIdentity.Accounts.Internal.User{},
         %{
           email: email,
           password: System.get_env("BORUTA_ADMIN_PASSWORD"),
           password_confirmation: System.get_env("BORUTA_ADMIN_PASSWORD"),
           confirmed_at: DateTime.utc_now()
         },
         %{backend: backend}
       )
       |> BorutaIdentity.Repo.insert() do
    {:ok, user} ->
      user = BorutaIdentity.Accounts.Internal.domain_user!(user, backend)

      admin_scopes
      |> Enum.map(fn %{id: scope_id} ->
        %BorutaIdentity.Accounts.UserAuthorizedScope{
          scope_id: scope_id,
          user_id: user.id
        }
        |> Ecto.Changeset.change()
        |> BorutaIdentity.Repo.insert(on_conflict: :nothing)
      end)

    {:error, _error} ->
      nil
  end
