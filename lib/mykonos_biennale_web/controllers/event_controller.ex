defmodule MykonosBiennaleWeb.EventController do
  use MykonosBiennaleWeb, :controller

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}
  alias MykonosBiennaleWeb.EventHTML

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
    biennale = get_event_biennale(event)
    show_project = Map.get(event.fields, "show_project", true)

    artboard_media_ids =
      event.fields
      |> Map.get("artboard_media_ids", [])
      |> Enum.map(fn id -> if is_binary(id), do: String.to_integer(id), else: id end)

    poster = get_event_poster(event)

    {artworks, films} =
      if show_project do
        project = get_event_project(event)
        project_artworks = get_project_artworks(event, project)
        project_films = get_project_films(event, project)
        {project_artworks, project_films}
      else
        {get_event_artworks(event), get_event_films(event)}
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

    participants = get_event_participants(event)

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
    |> put_view(EventHTML)
    |> render(template)
  end

  defp get_event_poster(event) do
    case Content.get_event_poster_link(event) do
      nil -> nil
      link -> link.media
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
        from m in Content.Media,
          where: m.id in ^media_ids
      )

    Enum.sort_by(records, fn m ->
      Enum.find_index(media_ids, &(&1 == m.id))
    end)
  end

  defp get_event_biennale(event) do
    rt = Repo.get_by(RelationshipType, slug: "biennale_event")

    if rt do
      case Repo.one(
             from r in Relationship,
               where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
               limit: 1,
               select: r.object_id
           ) do
        nil -> nil
        biennale_id -> Repo.get(Entity, biennale_id)
      end
    else
      nil
    end
  end

  defp get_event_project(event) do
    rt = Repo.get_by(RelationshipType, slug: "event_project")

    if rt do
      case Repo.one(
             from r in Relationship,
               where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
               limit: 1,
               select: r.object_id
           ) do
        nil -> nil
        project_id -> Repo.get(Entity, project_id)
      end
    else
      nil
    end
  end

  defp get_project_artworks(event, project) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")
    ep_rt = Repo.get_by(RelationshipType, slug: "event_project")

    if rt && ep_rt && project do
      sibling_event_ids = get_sibling_event_ids(event, project, ep_rt)

      artwork_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id in ^sibling_event_ids and r.relationship_type_id == ^rt.id,
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
        creators_by_id = batch_creators(artwork_ids)

        Enum.map(artworks, fn artwork ->
          %{
            artwork: artwork,
            media: Map.get(media_by_id, artwork.id, []),
            creators: Map.get(creators_by_id, artwork.id, [])
          }
        end)
      end
    else
      get_event_artworks(event)
    end
  end

  defp get_project_films(event, project) do
    rt = Repo.get_by(RelationshipType, slug: "screened_at")
    ep_rt = Repo.get_by(RelationshipType, slug: "event_project")

    if rt && ep_rt && project do
      sibling_event_ids = get_sibling_event_ids(event, project, ep_rt)

      film_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id in ^sibling_event_ids and r.relationship_type_id == ^rt.id,
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
    else
      get_event_films(event)
    end
  end

  defp get_sibling_event_ids(event, project, ep_rt) do
    be_rt = Repo.get_by(RelationshipType, slug: "biennale_event")

    biennale_id =
      if be_rt do
        Repo.one(
          from r in Relationship,
            where: r.subject_id == ^event.id and r.relationship_type_id == ^be_rt.id,
            limit: 1,
            select: r.object_id
        )
      else
        nil
      end

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

      Enum.filter(all_project_event_ids, &(&1 in same_biennale_event_ids))
    else
      all_project_event_ids
    end
  end

  defp get_event_artworks(event) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt do
      artwork_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id == ^event.id and r.relationship_type_id == ^rt.id,
            select: r.subject_id
        )

      if artwork_ids == [] do
        []
      else
        artworks =
          Repo.all(
            from e in Entity,
              where: e.id in ^artwork_ids and e.visible == true,
              order_by: [desc: fragment("? ->> ?", e.fields, "date")]
          )

        media_by_id = batch_media(artwork_ids)
        creators_by_id = batch_creators(artwork_ids)

        Enum.map(artworks, fn artwork ->
          %{
            artwork: artwork,
            media: Map.get(media_by_id, artwork.id, []),
            creators: Map.get(creators_by_id, artwork.id, [])
          }
        end)
      end
    else
      []
    end
  end

  defp get_event_films(event) do
    rt = Repo.get_by(RelationshipType, slug: "screened_at")

    if rt do
      film_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id == ^event.id and r.relationship_type_id == ^rt.id,
            select: r.subject_id
        )

      if film_ids == [] do
        []
      else
        films =
          Repo.all(
            from e in Entity,
              where: e.id in ^film_ids and e.visible == true,
              order_by: [asc: fragment("lower(? ->> ?)", e.fields, "title")]
          )

        media_by_id = batch_media(film_ids)

        Enum.map(films, fn film ->
          %{
            film: film,
            media: Map.get(media_by_id, film.id, [])
          }
        end)
      end
    else
      []
    end
  end

  defp get_event_participants(event) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
      |> Enum.map(& &1.object)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp batch_media(artwork_ids) do
    records =
      Repo.all(
        from em in Content.EntityMedia,
          where: em.entity_id in ^artwork_ids,
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

  defp batch_creators(artwork_ids) do
    ap_rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if ap_rt do
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
