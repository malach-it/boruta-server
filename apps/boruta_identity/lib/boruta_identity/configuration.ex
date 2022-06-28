defmodule BorutaIdentity.Configuration do
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  alias BorutaIdentity.Configuration.ErrorTemplate
  alias BorutaIdentity.Repo

  def get_error_template(type) do
    case Repo.get_by(ErrorTemplate, type: to_string(type)) do
      nil -> ErrorTemplate.default_template(type)
      template -> template
    end
  end

  def upsert_error_template(%ErrorTemplate{id: template_id} = template, attrs) do
    changeset = ErrorTemplate.changeset(template, attrs)

    case template_id do
      nil -> Repo.insert(changeset)
      _ -> Repo.update(changeset)
    end
  end

  def delete_error_template!(type) do
    template_type = to_string(type)

    with {1, _results} <-
           Repo.delete_all(
             from(t in ErrorTemplate,
               where: t.type == ^template_type
             )
           ),
         %ErrorTemplate{} = template <- get_error_template(type) do
      template
    else
      {0, nil} -> raise Ecto.NoResultsError, queryable: ErrorTemplate
    end
  end
end
