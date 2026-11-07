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

    total_events =
      Repo.one(from e in Entity, where: e.type == "event", select: count(e.id))

    total_participants =
      Repo.one(from e in Entity, where: e.type == "participant", select: count(e.id))

    total_artworks =
      Repo.one(from e in Entity, where: e.type == "artwork", select: count(e.id))

    total_films =
      Repo.one(from e in Entity, where: e.type in ^@film_types, select: count(e.id))

    total_media = Repo.one(from m in "media", select: count(m.id))

    cache_stats = Thumbnail.cache_stats()

    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign(:biennales, biennales)
      |> assign(:biennale_filter, "all")
      |> assign(:total_biennales, length(biennales))
      |> assign(:total_events, total_events)
      |> assign(:total_participants, total_participants)
      |> assign(:total_artworks, total_artworks)
      |> assign(:total_films, total_films)
      |> assign(:total_media, total_media)
      |> assign(:type_labels, @type_labels)
      |> assign(:type_colors, @type_colors)
      |> assign(:type_icons, @type_icons)
      |> assign(:cache_files, cache_stats.files)
      |> assign(:cache_size, format_bytes(cache_stats.bytes))
      |> assign_default_year()

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
  def handle_event("set_default_year", %{"year" => year}, socket) do
    year = String.to_integer(year)
    :ok = MykonosBiennale.Settings.put_current_biennale_year(year)

    {:noreply,
     socket
     |> assign(:current_biennale_year, year)
     |> put_flash(:info, "Default biennale set to #{year}")}
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

  defp assign_default_year(socket) do
    years =
      socket.assigns.biennales
      |> Enum.map(fn b ->
        case b.fields["year"] do
          year when is_integer(year) -> year
          year -> String.to_integer(to_string(year))
        end
      end)
      |> Enum.sort(:desc)

    socket
    |> assign(:current_biennale_year, MykonosBiennale.Settings.current_biennale_year())
    |> assign(:year_options, years)
  end

  defp load_recent(socket) do
    filter = socket.assigns.biennale_filter

    scoped_clause =
      if filter && filter != "all" do
        biennale_id = String.to_integer(filter)
        scoped_ids = get_biennale_entity_ids(biennale_id)

        if scoped_ids == [] do
          "AND 1=0"
        else
          "AND e.id IN (#{Enum.join(scoped_ids, ",")})"
        end
      else
        ""
      end

    types_list =
      @content_types
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(",")

    sql = """
    SELECT e.id, e.identity, e.type, e.fields, e.updated_at, e.inserted_at,
      COALESCE(
        (SELECT string_agg(p.identity, ', ')
         FROM relationships r
         JOIN relationship_types rt ON rt.id = r.relationship_type_id
         JOIN entities p ON p.id = r.object_id
         WHERE r.subject_id = e.id
           AND rt.slug IN ('artwork_participant', 'directed')
           AND p.type = 'participant'),
        ''
      ) as creators,
      COALESCE(
        (SELECT string_agg(COALESCE(ev.fields->>'title', ev.identity), ', ')
         FROM relationships r
         JOIN relationship_types rt ON rt.id = r.relationship_type_id
         JOIN entities ev ON ev.id = r.object_id
         WHERE r.subject_id = e.id
           AND rt.slug IN ('artwork_event', 'screened_at')
           AND ev.type = 'event'),
        ''
      ) as events
    FROM entities e
    WHERE e.type IN (#{types_list})
      AND e.visible = true
      #{scoped_clause}
    ORDER BY e.updated_at DESC
    LIMIT 30
    """

    {:ok, result} = Repo.query(sql)

    recent =
      Enum.map(result.rows, fn row ->
        [id, identity, type, fields, updated_at, inserted_at, creators, events] = row

        title = fields["title"] || fields["name"] || identity
        subtitle = build_subtitle(type, title, fields, creators, events)

        %{
          id: id,
          type: type,
          title: title,
          subtitle: subtitle,
          inserted_at: inserted_at,
          updated_at: updated_at,
          is_new: inserted_at == updated_at
        }
      end)

    assign(socket, :recent, recent)
  end

  defp build_subtitle("artwork", _title, _fields, creators, events) do
    parts = []
    parts = if creators != "", do: parts ++ ["Artwork by #{creators}"], else: parts
    parts = if events != "", do: parts ++ ["in #{events}"], else: parts
    Enum.join(parts, ", ")
  end

  defp build_subtitle(type, _title, _fields, creators, events) when type in @film_types do
    parts = []
    parts = if creators != "", do: parts ++ [creators], else: parts
    parts = if events != "", do: parts ++ ["in #{events}"], else: parts

    if parts == [],
      do: @type_labels[type] || type,
      else: "#{@type_labels[type] || type} by #{Enum.join(parts, ", ")}"
  end

  defp build_subtitle("participant", _title, _fields, _creators, events) do
    if events != "", do: "in #{events}", else: "Participant"
  end

  defp build_subtitle("event", _title, fields, _creators, _events) do
    fields["date"] || "Event"
  end

  defp build_subtitle(type, _title, _fields, _creators, _events) do
    @type_labels[type] || type
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

        <div class="mb-8 bg-gray-900/50 border border-gray-800 rounded-lg p-5">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h2 class="text-sm font-bold uppercase text-gray-300">Default Biennale</h2>
              <p class="text-2xl font-bold text-red-500 mt-1">{@current_biennale_year}</p>
              <p class="text-xs text-gray-500 mt-1">Shown on the home page</p>
            </div>
            <form phx-submit="set_default_year" class="flex items-center gap-2">
              <select
                name="year"
                class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-white"
              >
                <option
                  :for={year <- @year_options}
                  value={year}
                  selected={year == @current_biennale_year}
                >
                  {year}
                </option>
              </select>
              <button type="submit" class="btn btn-primary">Set default</button>
            </form>
          </div>
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
