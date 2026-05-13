defmodule MykonosBiennaleWeb.Admin.RelationshipLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Relationship, RelationshipType, Entity}
  alias MykonosBiennale.Search

  @impl true
  def mount(_params, _session, socket) do
    relationship_types = Content.list_relationship_types()

    {:ok,
     socket
     |> assign(:page_title, "Relationships")
     |> assign(:relationship_types, relationship_types)
     |> assign(:relationship, nil)
     |> assign(:search, "")
     |> stream(:relationships, list_relationships_filtered(""))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    rel = Content.get_relationship!(id)
    socket |> assign(:page_title, "Edit Relationship") |> assign(:relationship, rel)
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Relationship") |> assign(:relationship, %Relationship{})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Relationships") |> assign(:relationship, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.RelationshipLive.FormComponent, {:saved, _rel}},
        socket
      ) do
    {:noreply, stream(socket, :relationships, list_relationships_filtered(socket.assigns.search), reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    rel = Repo.get!(Relationship, String.to_integer(id))
    {:ok, _} = Content.delete_relationship(rel)
    {:noreply, stream_delete(socket, :relationships, rel)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply,
     socket
     |> assign(:search, term)
     |> stream(:relationships, list_relationships_filtered(term), reset: true)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> stream(:relationships, list_relationships_filtered(""), reset: true)}
  end

  defp list_relationships_filtered(""), do: list_relationships_preloaded()
  defp list_relationships_filtered(term) do
    pattern = Search.entity_search_pattern(term)

    # Match relationships where the subject's search_index, the object's
    # search_index, or the relationship_type slug/label matches.
    Repo.all(
      from r in Relationship,
        join: s in Entity,
        on: s.id == r.subject_id,
        join: o in Entity,
        on: o.id == r.object_id,
        join: rt in RelationshipType,
        on: rt.id == r.relationship_type_id,
        where:
          like(s.search_index, ^pattern) or
            like(o.search_index, ^pattern) or
            like(rt.slug, ^pattern) or
            like(rt.label, ^pattern),
        preload: [:subject, :object, :relationship_type],
        order_by: [desc: r.inserted_at]
    )
  end

  defp list_relationships_preloaded do
    Repo.all(
      from r in Relationship,
        preload: [:subject, :object, :relationship_type],
        order_by: [desc: r.inserted_at]
    )
  end

  defp entity_label(%Content.Entity{identity: identity}) when is_binary(identity) and identity != "",
    do: identity

  defp entity_label(%Content.Entity{fields: fields}) when is_map(fields) do
    Map.get(fields, "name") ||
      "#{Map.get(fields, "first_name", "")} #{Map.get(fields, "last_name", "")}"
      |> String.trim()
  end

  defp entity_label(%Content.Entity{id: id}), do: "##{id}"

  defp entity_type_badge(%Content.Entity{type: type}), do: type

  defp entity_path(%Content.Entity{type: "participant"} = e), do: "/admin/participants/#{e.id}"
  defp entity_path(%Content.Entity{type: "artwork"} = e), do: "/admin/artworks/#{e.id}"
  defp entity_path(%Content.Entity{type: "event"} = e), do: "/admin/events/#{e.id}"
  defp entity_path(%Content.Entity{type: "biennale"} = e), do: "/admin/biennales/#{e.id}"
  defp entity_path(%Content.Entity{type: "project"} = e), do: "/admin/projects/#{e.id}"
  defp entity_path(%Content.Entity{type: "festival"} = e), do: "/admin/festivals/#{e.id}"
  defp entity_path(%Content.Entity{} = e) do
    film_types = ["Short Film", "Video", "Dance", "Animation", "Documentary"]
    if e.type in film_types, do: "/admin/films/#{e.id}", else: "#"
  end

  defp format_fields(nil), do: ""
  defp format_fields(fields) when is_map(fields) do
    fields |> Enum.map(fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")
  end
end
