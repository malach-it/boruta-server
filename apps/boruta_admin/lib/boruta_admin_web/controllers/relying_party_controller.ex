defmodule BorutaAdminWeb.RelyingPartyController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.RelyingParties.Template

  action_fallback(BorutaAdminWeb.FallbackController)

  plug(:authorize, ["relying-parties:manage:all"])

  def index(conn, _params) do
    relying_parties = RelyingParties.list_relying_parties()
    render(conn, "index.json", relying_parties: relying_parties)
  end

  def create(conn, %{"relying_party" => relying_party_params}) do
    with {:ok, %RelyingParty{} = relying_party} <-
           RelyingParties.create_relying_party(relying_party_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_relying_party_path(conn, :show, relying_party))
      |> render("show.json", relying_party: relying_party)
    end
  end

  def show(conn, %{"id" => id}) do
    relying_party = RelyingParties.get_relying_party!(id)
    render(conn, "show.json", relying_party: relying_party)
  end

  def template(conn, %{"relying_party_id" => id, "template_type" => template_type}) do
    template = RelyingParties.get_relying_party_template!(id, String.to_atom(template_type))
    render(conn, "show_template.json", template: template)
  end

  def update(conn, %{"id" => id, "relying_party" => relying_party_params}) do
    relying_party = RelyingParties.get_relying_party!(id)

    with {:ok, %RelyingParty{} = relying_party} <-
           RelyingParties.update_relying_party(relying_party, relying_party_params) do
      render(conn, "show.json", relying_party: relying_party)
    end
  end

  def update_template(conn, %{
        "relying_party_id" => id,
        "template_type" => template_type,
        "template" => template_params
      }) do
    template = RelyingParties.get_relying_party_template!(id, String.to_atom(template_type))

    with {:ok, %Template{} = template} <-
           RelyingParties.upsert_template(template, template_params) do
      render(conn, "show_template.json", template: template)
    end
  end

  def delete_template(conn, %{"relying_party_id" => id, "template_type" => template_type}) do
    template = RelyingParties.delete_relying_party_template!(id, String.to_atom(template_type))
    render(conn, "show_template.json", template: template)
  end

  def delete(conn, %{"id" => id}) do
    relying_party = RelyingParties.get_relying_party!(id)

    # TODO cannot delete admin UI relying party
    with {:ok, %RelyingParty{}} <- RelyingParties.delete_relying_party(relying_party) do
      send_resp(conn, :no_content, "")
    end
  end
end
