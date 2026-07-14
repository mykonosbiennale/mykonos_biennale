defmodule MykonosBiennaleWeb.Admin.RelationshipLive.Show do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    rel = Content.get_relationship!(id)

    {:noreply,
     socket
     |> assign(:page_title, "Relationship ##{rel.id}")
     |> assign(:relationship, rel)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Content.delete_relationship(socket.assigns.relationship)
    {:noreply, push_navigate(socket, to: "/admin/relationships")}
  end

  defp entity_label(%Content.Entity{identity: identity})
       when is_binary(identity) and identity != "",
       do: identity

  defp entity_label(%Content.Entity{fields: fields}) when is_map(fields) do
    Map.get(fields, "name") ||
      "#{Map.get(fields, "first_name", "")} #{Map.get(fields, "last_name", "")}"
      |> String.trim()
  end

  defp entity_label(%Content.Entity{id: id}), do: "##{id}"

  defp entity_admin_path(%Content.Entity{type: "participant"} = e),
    do: "/admin/participants/#{e.id}"

  defp entity_admin_path(%Content.Entity{type: "artwork"} = e),
    do: "/admin/artworks/#{e.id}"

  defp entity_admin_path(%Content.Entity{type: "event"} = e),
    do: "/admin/events/#{e.id}"

  defp entity_admin_path(%Content.Entity{type: "biennale"} = e),
    do: "/admin/biennales/#{e.id}"

  defp entity_admin_path(%Content.Entity{type: "project"} = e),
    do: "/admin/projects/#{e.id}"

  defp entity_admin_path(%Content.Entity{} = e) do
    film_types = ["Short Film", "Video", "Dance", "Animation", "Documentary"]
    if e.type in film_types, do: "/admin/films/#{e.id}", else: "#"
  end

  defp format_fields(nil), do: ""

  defp format_fields(fields) when is_map(fields) do
    Enum.map_join(fields, ", ", fn {k, v} -> "#{k}: #{v}" end)
  end
end
