defmodule BorutaIdentity.ConfigurationTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Configuration
  alias BorutaIdentity.Configuration.ErrorTemplate
  alias BorutaIdentity.Repo

  describe "get_error_template!/1" do
    test "returns nil with unexisting template" do
      assert_raise Ecto.NoResultsError, fn ->
        Configuration.get_error_template!(:unexisting) == nil
      end
    end

    test "returns default template" do
      template = Configuration.get_error_template!(400)

      assert template == ErrorTemplate.default_template(400)
    end

    test "returns error template" do
      template =
        insert(:error_template,
          content: "custom registration template"
        )

      assert Configuration.get_error_template!(400) == template
    end
  end

  describe "upsert_error_template/1" do
    test "inserts with a default template" do
      template = Configuration.get_error_template!(400)

      assert {:ok, template} = Configuration.upsert_error_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end

    test "updates with an existing template" do
      template = insert(:error_template)

      assert {:ok, template} = Configuration.upsert_error_template(template, %{content: "new content"})

      assert Repo.reload(template)
    end
  end

  describe "delete_error_template!/2" do
    test "raises an error with unexisting template" do
      assert_raise Ecto.NoResultsError, fn ->
        Configuration.delete_error_template!(:unexisting)
      end
    end

    test "returns an error if template is default" do
      assert_raise Ecto.NoResultsError, fn ->
        Configuration.delete_error_template!(400)
      end
    end

    test "deletes and returns error template" do
      template =
        insert(:error_template,
          content: "custom registration template"
        )

      default_template = ErrorTemplate.default_template(400)

      reseted_template =
        Configuration.delete_error_template!(400)

      assert reseted_template.default == true
      assert reseted_template.type == "400"
      assert reseted_template.content == default_template.content

      assert Repo.get_by(ErrorTemplate, id: template.id) == nil
    end
  end
end
