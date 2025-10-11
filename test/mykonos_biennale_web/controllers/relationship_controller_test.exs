defmodule MykonosBiennaleWeb.RelationshipControllerTest do
  use MykonosBiennaleWeb.ConnCase

  import MykonosBiennale.DataFixtures
  alias MykonosBiennale.Data.Relationship

  @create_attrs %{
    name: "some name",
    fields: %{},
    slug: "some slug"
  }
  @update_attrs %{
    name: "some updated name",
    fields: %{},
    slug: "some updated slug"
  }
  @invalid_attrs %{name: nil, fields: nil, slug: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all relationships", %{conn: conn} do
      conn = get(conn, ~p"/api/relationships")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create relationship" do
    test "renders relationship when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/relationships", relationship: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/relationships/#{id}")

      assert %{
               "id" => ^id,
               "fields" => %{},
               "name" => "some name",
               "slug" => "some slug"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/relationships", relationship: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update relationship" do
    setup [:create_relationship]

    test "renders relationship when data is valid", %{conn: conn, relationship: %Relationship{id: id} = relationship} do
      conn = put(conn, ~p"/api/relationships/#{relationship}", relationship: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/relationships/#{id}")

      assert %{
               "id" => ^id,
               "fields" => %{},
               "name" => "some updated name",
               "slug" => "some updated slug"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, relationship: relationship} do
      conn = put(conn, ~p"/api/relationships/#{relationship}", relationship: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relationship" do
    setup [:create_relationship]

    test "deletes chosen relationship", %{conn: conn, relationship: relationship} do
      conn = delete(conn, ~p"/api/relationships/#{relationship}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/relationships/#{relationship}")
      end
    end
  end

  defp create_relationship(_) do
    relationship = relationship_fixture()

    %{relationship: relationship}
  end
end
