defmodule MykonosBiennaleWeb.Admin.DashboardLive do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Content
  alias MykonosBiennale.Thumbnail

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  @content_types ["participant", "artwork" | @film_types] ++
                   ["event", "biennale", "page", "section"]

  @type_labels %{
    "participant" => "Participant",
    "artwork" => "Artwork",
    "event" => "Event",
    "biennale" => "Biennale",
    "page" => "Page",
    "section" => "Section",
    "Short Film" => "Film",
    "Video" => "Video",
    "Dance" => "Dance",
    "Animation" => "Animation",
    "Documentary" => "Documentary"
  }

  @type_colors %{
    "participant" => "text-green-400",
    "artwork" => "text-red-400",
    "event" => "text-blue-400",
    "biennale" => "text-purple-400",
    "page" => "text-gray-400",
    "section" => "text-gray-400",
    "Short Film" => "text-cyan-400",
    "Video" => "text-cyan-400",
    "Dance" => "text-cyan-400",
    "Animation" => "text-cyan-400",
    "Documentary" => "text-cyan-400"
  }

  @type_icons %{
    "participant" => "hero-user-group",
    "artwork" => "hero-paint-brush",
    "event" => "hero-star",
    "biennale" => "hero-calendar",
    "page" => "hero-document",
    "section" => "hero-squares-2x2",
    "Short Film" => "hero-film",
    "Video" => "hero-film",
    "Dance" => "hero-film",
    "Animation" => "hero-film",
    "Documentary" => "hero-film"
  }

  @impl true
  def mount(_params, _session, socket) do
    import Ecto.Query, warn: false

    biennales = Content.list_biennales()

    all_events = Content.list_events()
    participants = Content.list_participants()
    artworks = Content.list_artworks()
    total_media = length(Content.list_media())

    total_films =
      Repo.one(from e in Entity, where: e.type in ^@film_types, select: count(e.id))

    cache_stats = Thumbnail.cache_stats()

    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign(:biennales, biennales)
      |> assign(:biennale_filter, "all")
      |> assign(:total_biennales, length(biennales))
      |> assign(:total_events, length(all_events))
      |> assign(:total_participants, length(participants))
      |> assign(:total_artworks, length(artworks))
      |> assign(:total_films, total_films)
      |> assign(:total_media, total_media)
      |> assign(:type_labels, @type_labels)
      |> assign(:type_colors, @type_colors)
      |> assign(:type_icons, @type_icons)
      |> assign(:cache_files, cache_stats.files)
      |> assign(:cache_size, format_bytes(cache_stats.bytes))

    {:ok, load_recent(socket)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_biennale", %{"biennale" => value}, socket) do
    {:noreply, socket |> assign(:biennale_filter, value) |> load_recent()}
  end

  @impl true
  def handle_event("clear_thumbnail_cache", _params, socket) do
    count = Thumbnail.clear_all_cache()
    legacy_count = Thumbnail.clear_legacy_cache()
    cache_stats = Thumbnail.cache_stats()

    {:noreply,
     socket
     |> assign(:cache_files, cache_stats.files)
     |> assign(:cache_size, format_bytes(cache_stats.bytes))
     |> put_flash(
       :info,
       "Cleared #{count + legacy_count} cached thumbnail(s). They will regenerate on next access."
     )}
  end

  defp load_recent(socket) do
    import Ecto.Query, warn: false

    filter = socket.assigns.biennale_filter

    base_query =
      from e in Entity,
        where: e.type in ^@content_types and e.visible == true,
        order_by: [desc: e.updated_at],
        limit: 30

    query =
      if filter && filter != "all" do
        biennale_id = String.to_integer(filter)
        scoped_ids = get_biennale_entity_ids(biennale_id)

        from e in base_query,
          where: e.id in ^scoped_ids
      else
        base_query
      end

    recent =
      Repo.all(query)
      |> Enum.map(fn entity ->
        %{
          id: entity.id,
          identity: entity.identity,
          type: entity.type,
          title: entity.fields["title"] || entity.fields["name"] || entity.identity,
          fields: entity.fields,
          inserted_at: entity.inserted_at,
          updated_at: entity.updated_at,
          is_new: entity.inserted_at == entity.updated_at
        }
      end)

    recent = enrich_with_context(recent)

    assign(socket, :recent, recent)
  end

  defp enrich_with_context(recent) do
    import Ecto.Query, warn: false

    artwork_ids = for %{type: "artwork", id: id} <- recent, do: id
    film_ids = for %{type: t, id: id} <- recent, t in @film_types, do: id
    participant_ids = for %{type: "participant", id: id} <- recent, do: id

    all_subject_ids = artwork_ids ++ film_ids ++ participant_ids
    all_object_ids = artwork_ids ++ film_ids

    ap_rt = Repo.get_by(RelationshipType, slug: "artwork_participant")
    ae_rt = Repo.get_by(RelationshipType, slug: "artwork_event")
    directed_rt = Repo.get_by(RelationshipType, slug: "directed")
    screened_at_rt = Repo.get_by(RelationshipType, slug: "screened_at")

    creator_names = load_creators(all_subject_ids, ap_rt, directed_rt)
    event_names = load_events(all_object_ids, ae_rt, screened_at_rt)

    Enum.map(recent, fn item ->
      subtitle = build_subtitle(item, creator_names, event_names)
      Map.put(item, :subtitle, subtitle)
    end)
  end

  defp load_creators(ids, ap_rt, directed_rt) do
    import Ecto.Query, warn: false

    ap_ids = if ap_rt && ids != [], do: ids, else: []
    directed_ids = if directed_rt && ids != [], do: ids, else: []

    ap_rels =
      if ap_ids != [] do
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^ap_ids and r.relationship_type_id == ^ap_rt.id,
            preload: [:object]
        )
      else
        []
      end

    directed_rels =
      if directed_ids != [] do
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^directed_ids and r.relationship_type_id == ^directed_rt.id,
            preload: [:object]
        )
      else
        []
      end

    (ap_rels ++ directed_rels)
    |> Enum.group_by(& &1.subject_id)
    |> Enum.into(%{}, fn {id, rels} ->
      names = rels |> Enum.map(& &1.object.identity) |> Enum.reject(&is_nil/1)
      {id, names}
    end)
  end

  defp load_events(ids, ae_rt, screened_at_rt) do
    import Ecto.Query, warn: false

    ae_ids = if ae_rt && ids != [], do: ids, else: []
    sa_ids = if screened_at_rt && ids != [], do: ids, else: []

    ae_rels =
      if ae_ids != [] do
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^ae_ids and r.relationship_type_id == ^ae_rt.id,
            preload: [:object]
        )
      else
        []
      end

    sa_rels =
      if sa_ids != [] do
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^sa_ids and r.relationship_type_id == ^screened_at_rt.id,
            preload: [:object]
        )
      else
        []
      end

    (ae_rels ++ sa_rels)
    |> Enum.group_by(& &1.subject_id)
    |> Enum.into(%{}, fn {id, rels} ->
      titles =
        rels
        |> Enum.map(fn r -> r.object.fields["title"] || r.object.identity end)
        |> Enum.reject(&is_nil/1)

      {id, titles}
    end)
  end

  defp build_subtitle(%{type: "artwork"} = item, creator_names, event_names) do
    creators = Map.get(creator_names, item.id, [])
    events = Map.get(event_names, item.id, [])

    parts = []

    parts =
      if creators != [], do: parts ++ ["Artwork by #{Enum.join(creators, ", ")}"], else: parts

    parts = if events != [], do: parts ++ ["in #{Enum.join(events, ", ")}"], else: parts
    Enum.join(parts, ", ")
  end

  defp build_subtitle(%{type: type} = item, creator_names, event_names)
       when type in @film_types do
    creators = Map.get(creator_names, item.id, [])
    events = Map.get(event_names, item.id, [])

    parts = []
    parts = if creators != [], do: parts ++ ["#{Enum.join(creators, ", ")}"], else: parts
    parts = if events != [], do: parts ++ ["in #{Enum.join(events, ", ")}"], else: parts

    label =
      if parts == [],
        do: @type_labels[item.type] || item.type,
        else: "#{@type_labels[item.type] || item.type} by #{Enum.join(parts, ", ")}"

    label
  end

  defp build_subtitle(%{type: "participant"} = item, _creator_names, event_names) do
    events = Map.get(event_names, item.id, [])
    if events != [], do: "in #{Enum.join(events, ", ")}", else: "Participant"
  end

  defp build_subtitle(%{type: "event"} = item, _creator_names, _event_names) do
    item.fields["date"] || "Event"
  end

  defp build_subtitle(item, _creator_names, _event_names) do
    @type_labels[item.type] || item.type
  end

  defp get_biennale_entity_ids(biennale_id) do
    import Ecto.Query, warn: false

    event_ids = rel_subject_ids(biennale_id, "biennale_event")
    artwork_ids = rel_subject_ids(event_ids, "artwork_event")
    film_ids = rel_subject_ids(event_ids, "screened_at")
    participant_ids = rel_object_ids(artwork_ids, "artwork_participant")

    (event_ids ++ artwork_ids ++ film_ids ++ participant_ids)
    |> MapSet.new()
    |> MapSet.to_list()
  end

  defp rel_subject_ids(biennale_id, slug) when is_integer(biennale_id) do
    import Ecto.Query, warn: false
    rt = Repo.get_by(RelationshipType, slug: slug)

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^biennale_id and r.relationship_type_id == ^rt.id,
          select: r.subject_id
      )
    else
      []
    end
  end

  defp rel_subject_ids(parent_ids, slug) when is_list(parent_ids) and parent_ids != [] do
    import Ecto.Query, warn: false
    rt = Repo.get_by(RelationshipType, slug: slug)

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.object_id in ^parent_ids and r.relationship_type_id == ^rt.id,
          select: r.subject_id
      )
    else
      []
    end
  end

  defp rel_subject_ids(_parent_ids, _slug), do: []

  defp rel_object_ids(parent_ids, slug) when is_list(parent_ids) and parent_ids != [] do
    import Ecto.Query, warn: false
    rt = Repo.get_by(RelationshipType, slug: slug)

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id in ^parent_ids and r.relationship_type_id == ^rt.id,
          select: r.object_id
      )
    else
      []
    end
  end

  defp rel_object_ids(_parent_ids, _slug), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="flex items-center gap-2 mb-8">
          <.link
            navigate={~p"/admin/events/new"}
            class="flex items-center gap-2 px-3 py-2 bg-blue-900/20 border border-blue-700/30 rounded-lg hover:border-blue-600/50 transition-colors"
            title="New Event"
          >
            <.icon name="hero-star" class="size-5 text-blue-400" />
            <.icon name="hero-plus" class="size-3 text-blue-400" />
          </.link>

          <.link
            navigate={~p"/admin/participants/new"}
            class="flex items-center gap-2 px-3 py-2 bg-green-900/20 border border-green-700/30 rounded-lg hover:border-green-600/50 transition-colors"
            title="New Participant"
          >
            <.icon name="hero-user-group" class="size-5 text-green-400" />
            <.icon name="hero-plus" class="size-3 text-green-400" />
          </.link>

          <.link
            navigate={~p"/admin/artworks/new"}
            class="flex items-center gap-2 px-3 py-2 bg-red-900/20 border border-red-700/30 rounded-lg hover:border-red-600/50 transition-colors"
            title="New Artwork"
          >
            <.icon name="hero-paint-brush" class="size-5 text-red-400" />
            <.icon name="hero-plus" class="size-3 text-red-400" />
          </.link>

          <.link
            patch={~p"/admin/films/new"}
            class="flex items-center gap-2 px-3 py-2 bg-cyan-900/20 border border-cyan-700/30 rounded-lg hover:border-cyan-600/50 transition-colors"
            title="New Film"
          >
            <.icon name="hero-film" class="size-5 text-cyan-400" />
            <.icon name="hero-plus" class="size-3 text-cyan-400" />
          </.link>

          <.link
            navigate={~p"/admin/media"}
            class="flex items-center gap-2 px-3 py-2 bg-amber-900/20 border border-amber-700/30 rounded-lg hover:border-amber-600/50 transition-colors"
            title="Media"
          >
            <.icon name="hero-photo" class="size-5 text-amber-400" />
          </.link>
        </div>

        <div class="mb-8">
          <h2 class="text-sm font-bold uppercase mb-4 text-gray-300">Browse</h2>
          <div class="flex flex-wrap gap-2">
            <.link
              navigate={~p"/admin/biennales"}
              class="flex items-center gap-1.5 px-3 py-1.5 bg-gray-900/50 border border-gray-800 rounded-full hover:border-purple-700/50 transition-colors"
            >
              <span class="text-xs text-gray-400">Biennales</span>
              <.icon name="hero-calendar" class="size-3.5 text-purple-400" />
              <span class="text-xs font-bold text-white">{@total_biennales}</span>
            </.link>

            <.link
              navigate={~p"/admin/events"}
              class="flex items-center gap-1.5 px-3 py-1.5 bg-gray-900/50 border border-gray-800 rounded-full hover:border-blue-700/50 transition-colors"
            >
              <span class="text-xs text-gray-400">Events</span>
              <.icon name="hero-star" class="size-3.5 text-blue-400" />
              <span class="text-xs font-bold text-white">{@total_events}</span>
            </.link>

            <.link
              navigate={~p"/admin/participants"}
              class="flex items-center gap-1.5 px-3 py-1.5 bg-gray-900/50 border border-gray-800 rounded-full hover:border-green-700/50 transition-colors"
            >
              <span class="text-xs text-gray-400">Participants</span>
              <.icon name="hero-user-group" class="size-3.5 text-green-400" />
              <span class="text-xs font-bold text-white">{@total_participants}</span>
            </.link>

            <.link
              navigate={~p"/admin/artworks"}
              class="flex items-center gap-1.5 px-3 py-1.5 bg-gray-900/50 border border-gray-800 rounded-full hover:border-red-700/50 transition-colors"
            >
              <span class="text-xs text-gray-400">Artworks</span>
              <.icon name="hero-paint-brush" class="size-3.5 text-red-400" />
              <span class="text-xs font-bold text-white">{@total_artworks}</span>
            </.link>

            <.link
              navigate={~p"/admin/films"}
              class="flex items-center gap-1.5 px-3 py-1.5 bg-gray-900/50 border border-gray-800 rounded-full hover:border-cyan-700/50 transition-colors"
            >
              <span class="text-xs text-gray-400">Films</span>
              <.icon name="hero-film" class="size-3.5 text-cyan-400" />
              <span class="text-xs font-bold text-white">{@total_films}</span>
            </.link>

            <.link
              navigate={~p"/admin/media"}
              class="flex items-center gap-1.5 px-3 py-1.5 bg-gray-900/50 border border-gray-800 rounded-full hover:border-amber-700/50 transition-colors"
            >
              <span class="text-xs text-gray-400">Media</span>
              <.icon name="hero-photo" class="size-3.5 text-amber-400" />
              <span class="text-xs font-bold text-white">{@total_media}</span>
            </.link>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-sm font-bold uppercase text-gray-300">Recent Changes</h2>
            <form phx-change="filter_biennale" class="flex items-center gap-2">
              <select
                name="biennale"
                class="bg-gray-900 border border-gray-700 text-gray-300 rounded text-xs px-2 py-1"
              >
                <option value="all" selected={@biennale_filter == "all"}>All biennales</option>
                <%= for b <- @biennales do %>
                  <option value={b.id} selected={@biennale_filter == to_string(b.id)}>
                    {b.fields["year"]}
                  </option>
                <% end %>
              </select>
            </form>
          </div>
          <div class="bg-gray-900/50 border border-gray-800 rounded-lg overflow-hidden">
            <div class="divide-y divide-gray-800">
              <%= for item <- @recent do %>
                <.link
                  navigate={entity_path(item)}
                  class="flex items-center gap-3 px-4 py-3 hover:bg-gray-800/50 transition-colors"
                >
                  <.icon
                    name={@type_icons[item.type] || "hero-document"}
                    class={"size-5 shrink-0 " <> (@type_colors[item.type] || "text-gray-400")}
                  />
                  <div class="min-w-0 flex-1">
                    <span class="text-sm text-white truncate block">{item.title}</span>
                    <%= if item[:subtitle] && item[:subtitle] != "" do %>
                      <span class="text-xs text-gray-500 truncate block">{item[:subtitle]}</span>
                    <% end %>
                  </div>
                  <div class="shrink-0 text-right">
                    <%= if item.is_new do %>
                      <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-900/40 text-green-400">
                        New
                      </span>
                    <% else %>
                      <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-900/40 text-blue-400">
                        Edited
                      </span>
                    <% end %>
                    <span class="text-xs text-gray-600 ml-2">{time_ago(item.updated_at)}</span>
                  </div>
                </.link>
              <% end %>
              <%= if @recent == [] do %>
                <div class="px-4 py-8 text-center text-sm text-gray-500">
                  No recent changes for this biennale.
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-8">
          <input type="checkbox" id="admin-system-toggle" class="hidden peer" />
          <label
            for="admin-system-toggle"
            class="flex items-center gap-2 text-sm font-bold uppercase text-gray-500 hover:text-gray-300 cursor-pointer mb-0"
          >
            <.icon
              name="hero-chevron-down"
              class="size-4 peer-checked:rotate-180 transition-transform"
            /> System
          </label>
          <div class="hidden peer-checked:block mt-4">
            <div class="bg-gray-900/50 border border-gray-800 rounded-lg p-5">
              <div class="flex items-center justify-between flex-wrap gap-4">
                <div>
                  <h3 class="font-bold text-white uppercase tracking-wider mb-1">Thumbnail Cache</h3>
                  <p class="text-sm text-gray-400">
                    {@cache_files} files · {@cache_size}
                  </p>
                </div>
                <button
                  phx-click="clear_thumbnail_cache"
                  data-confirm="Clear all cached thumbnails?"
                  class="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white text-sm font-medium rounded-lg transition-colors"
                >
                  Clear Cache
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp entity_path(%{type: "biennale", id: id}), do: "/admin/biennales/#{id}"
  defp entity_path(%{type: "event", id: id}), do: "/admin/events/#{id}"
  defp entity_path(%{type: "participant", id: id}), do: "/admin/participants/#{id}"
  defp entity_path(%{type: "artwork", id: id}), do: "/admin/artworks/#{id}"
  defp entity_path(%{type: type, id: id}) when type in @film_types, do: "/admin/films/#{id}"
  defp entity_path(%{type: "page", id: id}), do: "/admin/pages/#{id}"
  defp entity_path(%{type: "section", id: id}), do: "/admin/sections/#{id}"
  defp entity_path(%{id: id}), do: "/admin/entities/#{id}"

  defp time_ago(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(DateTime.to_date(dt), "%b %d")
    end
  end

  defp time_ago(%NaiveDateTime{} = dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> time_ago()
  end

  defp time_ago(_), do: ""

  defp format_bytes(bytes) when bytes >= 1_000_000_000,
    do: "#{Float.round(bytes / 1_000_000_000, 1)} GB"

  defp format_bytes(bytes) when bytes >= 1_000_000, do: "#{Float.round(bytes / 1_000_000, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_000, do: "#{Float.round(bytes / 1_000, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"
end
