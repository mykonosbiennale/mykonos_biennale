defmodule MykonosBiennaleWeb.RelationshipController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Data
  alias MykonosBiennale.Data.Relationship

  action_fallback MykonosBiennaleWeb.FallbackController

  def index(conn, _params) do
    relationships = Data.list_relationships()
    render(conn, :index, relationships: relationships)
  end

  def create(conn, %{"relationship" => relationship_params}) do
    with {:ok, %Relationship{} = relationship} <- Data.create_relationship(relationship_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/relationships/#{relationship}")
      |> render(:show, relationship: relationship)
    end
  end

  def show(conn, %{"id" => id}) do
    relationship = Data.get_relationship!(id)
    render(conn, :show, relationship: relationship)
  end

  def update(conn, %{"id" => id, "relationship" => relationship_params}) do
    relationship = Data.get_relationship!(id)

    with {:ok, %Relationship{} = relationship} <- Data.update_relationship(relationship, relationship_params) do
      render(conn, :show, relationship: relationship)
    end
  end

  def delete(conn, %{"id" => id}) do
    relationship = Data.get_relationship!(id)

    with {:ok, %Relationship{}} <- Data.delete_relationship(relationship) do
      send_resp(conn, :no_content, "")
    end
  end
end
