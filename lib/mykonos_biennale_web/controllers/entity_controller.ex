defmodule MykonosBiennaleWeb.EntityController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Data
  alias MykonosBiennale.Data.Entity

  action_fallback MykonosBiennaleWeb.FallbackController

  def index(conn, _params) do
    entities = Data.list_entities()
    render(conn, :index, entities: entities)
  end

  def create(conn, %{"entity" => entity_params}) do
    with {:ok, %Entity{} = entity} <- Data.create_entity(entity_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/entities/#{entity}")
      |> render(:show, entity: entity)
    end
  end

  def show(conn, %{"id" => id}) do
    entity = Data.get_entity!(id)
    render(conn, :show, entity: entity)
  end

  def update(conn, %{"id" => id, "entity" => entity_params}) do
    entity = Data.get_entity!(id)

    with {:ok, %Entity{} = entity} <- Data.update_entity(entity, entity_params) do
      render(conn, :show, entity: entity)
    end
  end

  def delete(conn, %{"id" => id}) do
    entity = Data.get_entity!(id)

    with {:ok, %Entity{}} <- Data.delete_entity(entity) do
      send_resp(conn, :no_content, "")
    end
  end
end
