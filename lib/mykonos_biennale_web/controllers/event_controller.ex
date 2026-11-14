defmodule MykonosBiennaleWeb.EventController do
  use MykonosBiennaleWeb, :controller

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, EntityMedia, Media, Relationship, RelationshipType}
  alias MykonosBiennaleWeb.EventHTML
  alias MykonosBiennaleWeb.Metadata

  def show(conn, %{"id" => id}) do
    case Repo.get(Entity, id) do
      %Entity{type: "event", visible: true} = event ->
        render_event(conn, event)

      _ ->
        not_found(conn)
    end
  end

  def show_by_slug(conn, %{"slug" => slug}) do
    case Repo.get_by(Entity, slug: slug, type: "event") do
      %Entity{visible: true} = event ->
        render_event(conn, event)

      _ ->
        not_found(conn)
    end
  end

  defp render_event(conn, event) do
    event_type = event.fields["type"] || "event"
    show_project = Map.get(event.fields, "show_project", true)

    artboard_media_ids =
      event.fields
      |> Map.get("artboard_media_ids", [])
      |> Enum.map(fn id -> if is_binary(id), do: String.to_integer(id), else: id end)

    # Preload all relationship types in one query
    rt = preload_relationship_types()

    # Single query: get both biennale_id and project_id for this event
    {biennale_id, project_id} = get_event_parents(event, rt)

    # Single query each for biennale and project entities
    {biennale, project} =
      case [biennale_id, project_id] |> Enum.reject(&is_nil/1) do
        [] ->
          {nil, nil}

        ids ->
          entities = Repo.all(from e in Entity, where: e.id in ^ids)

          {Enum.find(entities, &(&1.id == biennale_id)),
           Enum.find(entities, &(&1.id == project_id))}
      end

    poster = get_poster(event)

    {artworks, films} =
      if show_project && project do
        sibling_ids = get_sibling_event_ids(event, project, biennale_id, rt)
        {get_artworks_for_events(sibling_ids, rt), get_films_for_events(sibling_ids, rt)}
      else
        {get_artworks_for_events([event.id], rt), get_films_for_events([event.id], rt)}
      end

    artworks =
      if event_type == "exhibition" and artboard_media_ids != [] do
        filter_artworks_by_artboard(artworks, artboard_media_ids)
      else
        artworks
      end

    media =
      if event_type != "exhibition" and event_type != "screening" and artboard_media_ids != [] do
        load_artboard_media(artboard_media_ids)
      else
        Content.list_media_for_entity(event)
      end

    participants = get_event_participants(event, rt)

    template =
      case event_type do
        "exhibition" -> :exhibition
        "screening" -> :screening
        _ -> :default
      end

    conn
    |> assign(:event, event)
    |> assign(:event_type, event_type)
    |> assign(:biennale, biennale)
    |> assign(:artworks, artworks)
    |> assign(:films, films)
    |> assign(:media, media)
    |> assign(:poster, poster)
    |> assign(:participants, participants)
    |> assign(:page_title, "#{event.fields["title"] || "Event"} — Mykonos Biennale")
    |> assign(
      :seo,
      Metadata.for_event(event, Metadata.biennale_year(biennale), conn.request_path)
    )
    |> put_view(EventHTML)
    |> render(template)
  end

  defp preload_relationship_types do
    slugs = [
      "biennale_event",
      "event_project",
      "artwork_event",
      "screened_at",
      "artwork_participant"
    ]

    Repo.all(from rt in RelationshipType, where: rt.slug in ^slugs)
    |> Enum.into(%{}, fn rt -> {rt.slug, rt} end)
  end

  defp get_event_parents(event, rt) do
    be_rt = Map.get(rt, "biennale_event")
    ep_rt = Map.get(rt, "event_project")
    rt_ids = [be_rt && be_rt.id, ep_rt && ep_rt.id] |> Enum.reject(&is_nil/1)

    if rt_ids == [] do
      {nil, nil}
    else
      rows =
        Repo.all(
          from r in Relationship,
            where: r.subject_id == ^event.id and r.relationship_type_id in ^rt_ids,
            select: {r.relationship_type_id, r.object_id}
        )

      biennale_id =
        Enum.find_value(rows, fn {rt_id, oid} -> if be_rt && rt_id == be_rt.id, do: oid end)

      project_id =
        Enum.find_value(rows, fn {rt_id, oid} -> if ep_rt && rt_id == ep_rt.id, do: oid end)

      {biennale_id, project_id}
    end
  end

  defp get_sibling_event_ids(event, project, biennale_id, rt) do
    ep_rt = Map.get(rt, "event_project")
    be_rt = Map.get(rt, "biennale_event")

    if ep_rt == nil do
      [event.id]
    else
      all_project_event_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id == ^project.id and r.relationship_type_id == ^ep_rt.id,
            select: r.subject_id
        )

      if biennale_id && be_rt do
        same_biennale_event_ids =
          Repo.all(
            from r in Relationship,
              where: r.object_id == ^biennale_id and r.relationship_type_id == ^be_rt.id,
              select: r.subject_id
          )

        same_set = MapSet.new(same_biennale_event_ids)
        Enum.filter(all_project_event_ids, &MapSet.member?(same_set, &1))
      else
        all_project_event_ids
      end
    end
  end

  defp get_poster(event) do
    case Content.get_event_poster_link(event) do
      nil -> nil
      link -> link.media
    end
  end

  defp get_artworks_for_events(event_ids, rt) do
    ae_rt = Map.get(rt, "artwork_event")

    if ae_rt == nil or event_ids == [] do
      []
    else
      artwork_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id in ^event_ids and r.relationship_type_id == ^ae_rt.id,
            select: r.subject_id,
            distinct: true
        )

      if artwork_ids == [] do
        []
      else
        artworks =
          Repo.all(
            from e in Entity,
              where: e.id in ^artwork_ids and e.visible == true,
              order_by: [
                asc: fragment("lower(coalesce(? ->> ?, ?))", e.fields, "title", e.identity)
              ]
          )

        media_by_id = batch_media(artwork_ids)
        creators_by_id = batch_creators(artwork_ids, rt)

        Enum.map(artworks, fn artwork ->
          %{
            artwork: artwork,
            media: Map.get(media_by_id, artwork.id, []),
            creators: Map.get(creators_by_id, artwork.id, [])
          }
        end)
      end
    end
  end

  defp get_films_for_events(event_ids, rt) do
    sa_rt = Map.get(rt, "screened_at")

    if sa_rt == nil or event_ids == [] do
      []
    else
      film_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id in ^event_ids and r.relationship_type_id == ^sa_rt.id,
            select: r.subject_id,
            distinct: true
        )

      if film_ids == [] do
        []
      else
        films =
          Repo.all(
            from e in Entity,
              where: e.id in ^film_ids and e.visible == true,
              order_by: [
                asc: fragment("lower(coalesce(? ->> ?, ?))", e.fields, "title", e.identity)
              ]
          )

        media_by_id = batch_media(film_ids)

        Enum.map(films, fn film ->
          %{
            film: film,
            media: Map.get(media_by_id, film.id, [])
          }
        end)
      end
    end
  end

  defp get_event_participants(event, rt) do
    ap_rt = Map.get(rt, "artwork_participant")

    if ap_rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^event.id and r.relationship_type_id == ^ap_rt.id,
          preload: [:object]
      )
      |> Enum.map(& &1.object)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp filter_artworks_by_artboard(artworks, artboard_media_ids) do
    artboard_set = MapSet.new(artboard_media_ids)

    artworks
    |> Enum.map(fn item ->
      selected = Enum.filter(item.media, fn m -> MapSet.member?(artboard_set, m.id) end)
      if selected != [], do: %{item | media: selected}, else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp load_artboard_media(media_ids) do
    records =
      Repo.all(
        from m in Media,
          where: m.id in ^media_ids
      )

    Enum.sort_by(records, fn m ->
      Enum.find_index(media_ids, &(&1 == m.id))
    end)
  end

  defp batch_media(entity_ids) do
    records =
      Repo.all(
        from em in EntityMedia,
          where: em.entity_id in ^entity_ids,
          order_by: [
            asc:
              fragment(
                "CASE WHEN ? ->> 'is_poster' = 'true' OR ? ->> 'role' = 'poster' THEN 0 ELSE 1 END",
                em.metadata,
                em.metadata
              ),
            asc: em.position
          ],
          preload: [:media]
      )

    Enum.group_by(records, & &1.entity_id, & &1.media)
  end

  defp batch_creators(artwork_ids, rt) do
    ap_rt = Map.get(rt, "artwork_participant")

    if ap_rt && artwork_ids != [] do
      rels =
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^artwork_ids and r.relationship_type_id == ^ap_rt.id,
            preload: [:object]
        )

      rels
      |> Enum.group_by(& &1.subject_id)
      |> Enum.into(%{}, fn {artwork_id, rels} ->
        creators = rels |> Enum.map(& &1.object) |> Enum.reject(&is_nil/1)
        {artwork_id, creators}
      end)
    else
      %{}
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end
end
