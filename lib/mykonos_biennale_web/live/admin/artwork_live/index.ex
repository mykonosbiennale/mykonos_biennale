defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Artworks")
     |> assign(:search, "")
     |> assign(:creators_map, %{})
     |> assign(:events_map, %{})
     |> assign(:media_map, %{})
     |> assign(:artworks_loaded, false)
     |> stream(:artworks, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      if !socket.assigns.artworks_loaded do
        socket |> assign(:artworks_loaded, true) |> load_artworks()
      else
        socket
      end

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp load_artworks(socket) do
    artworks = list_artworks_filtered(socket.assigns.search)
    artwork_ids = Enum.map(artworks, & &1.id)

    socket
    |> assign(:creators_map, batch_load_creators(artwork_ids))
    |> assign(:events_map, batch_load_events(artwork_ids))
    |> assign(:media_map, batch_load_first_media(artwork_ids))
    |> stream(:artworks, artworks, reset: true)
  end

  defp list_artworks_filtered(""), do: Content.list_artworks()
  defp list_artworks_filtered(term) do
    pattern = Search.entity_search_pattern(term)

    Repo.all(
      from e in Entity,
        where: e.type == "artwork",
        where: not is_nil(e.search_index) and like(e.search_index, ^pattern),
        order_by: [desc: fragment("? ->> ?", e.fields, "date")]
    )
  end

  defp batch_load_creators(artwork_ids) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")
    if rt == nil or artwork_ids == [], do: %{}, else: do_batch_load_creators(rt.id, artwork_ids)
  end

  defp do_batch_load_creators(rt_id, artwork_ids) do
    Repo.all(
      from r in Relationship,
        where: r.relationship_type_id == ^rt_id and r.subject_id in ^artwork_ids,
        preload: [:object]
    )
    |> Enum.group_by(& &1.subject_id, fn r ->
      name = case r.object do
        nil -> "Unknown"
        p -> p.fields["name"] || "#{p.fields["first_name"] || ""} #{p.fields["last_name"] || ""}" |> String.trim()
      end
      %{id: r.object_id, name: name, role: r.fields["role"]}
    end)
  end

  defp batch_load_events(artwork_ids) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")
    if rt == nil or artwork_ids == [], do: %{}, else: do_batch_load_events(rt.id, artwork_ids)
  end

  defp do_batch_load_events(rt_id, artwork_ids) do
    Repo.all(
      from r in Relationship,
        where: r.relationship_type_id == ^rt_id and r.subject_id in ^artwork_ids,
        preload: [:object]
    )
    |> Enum.group_by(& &1.subject_id, fn r ->
      title = if r.object, do: r.object.fields["title"], else: "Unknown"
      %{id: r.object_id, title: title}
    end)
  end

  defp batch_load_first_media([]), do: %{}
  defp batch_load_first_media(artwork_ids) do
    Repo.all(
      from em in EntityMedia,
        where: em.entity_id in ^artwork_ids,
        join: m in Media, on: m.id == em.media_id,
        order_by: [em.entity_id, em.position],
        select: %{entity_id: em.entity_id, source_type: m.source_type, source_path: m.source_path, source_url: m.source_url}
    )
    |> Enum.group_by(& &1.entity_id)
    |> Enum.into(%{}, fn {eid, items} ->
      first = Enum.find(items, &(&1.source_type == "upload" and is_binary(&1.source_path))) ||
              Enum.find(items, &(&1.source_type == "url" and is_binary(&1.source_url)))
      {eid, first}
    end)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Artwork") |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket |> assign(:page_title, "Show Artwork") |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Artwork") |> assign(:artwork, %Content.Entity{type: "artwork", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Artworks") |> assign(:artwork, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:saved, _artwork}}, socket) do
    {:noreply, load_artworks(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    artwork = Content.get_artwork!(id)
    {:ok, _} = Content.delete_artwork(artwork)
    {:noreply, load_artworks(socket)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> load_artworks()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> load_artworks()}
  end

  defp field(entity, key, default \\ nil)
  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end
  defp field(%Content.Entity{}, _key, default), do: default
end
