defmodule MykonosBiennaleWeb.FilmController do
  use MykonosBiennaleWeb, :controller

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Film}
  alias MykonosBiennaleWeb.FilmHTML

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  def show(conn, %{"id" => id}) do
    case Repo.get(Entity, id) do
      %Entity{type: type, visible: true} = film when type in @film_types ->
        render_film(conn, film)

      _ ->
        not_found(conn)
    end
  end

  def show_by_slug(conn, %{"slug" => slug}) do
    case Repo.one(
           from e in Entity,
             where: e.slug == ^slug and e.type in ^@film_types
         ) do
      %Entity{visible: true} = film ->
        render_film(conn, film)

      _ ->
        not_found(conn)
    end
  end

  defp render_film(conn, film) do
    film = Film.get_for_show!(film.id)
    media_links = Content.list_entity_media_links_for_entity(film)
    poster = get_film_poster(media_links)
    stills = filter_stills(media_links)
    relationships = Film.list_relationships(film)
    events = list_film_events(film)
    biennale = get_event_biennale(events)
    crew = group_crew_by_role(relationships)

    conn
    |> assign(:film, film)
    |> assign(:poster, poster)
    |> assign(:stills, stills)
    |> assign(:events, events)
    |> assign(:biennale, biennale)
    |> assign(:crew, crew)
    |> assign(:page_title, "#{film.identity} — Mykonos Biennale")
    |> put_view(FilmHTML)
    |> render(:show)
  end

  defp get_film_poster(media_links) do
    Enum.find_value(media_links, fn link ->
      if link.metadata && (link.metadata["role"] == "poster" or link.metadata["is_poster"]),
        do: link.media
    end)
  end

  defp filter_stills(media_links) do
    media_links
    |> Enum.filter(fn link ->
      link.metadata && link.metadata["role"] in ["screenshot", "still"]
    end)
    |> Enum.map(& &1.media)
  end

  defp list_film_events(film) do
    rt = Repo.get_by(RelationshipType, slug: "screened_at")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^film.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
      |> Enum.map(& &1.object)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp get_event_biennale([]), do: nil

  defp get_event_biennale(events) do
    rt = Repo.get_by(RelationshipType, slug: "biennale_event")

    if rt do
      event_ids = Enum.map(events, & &1.id)

      Repo.one(
        from r in Relationship,
          where: r.subject_id in ^event_ids and r.relationship_type_id == ^rt.id,
          limit: 1,
          preload: [:object]
      )
      |> case do
        nil -> nil
        rel -> rel.object
      end
    else
      nil
    end
  end

  defp group_crew_by_role(relationships) do
    relationships
    |> Enum.reject(fn rel -> rel.relationship_type.slug == "screened_at" end)
    |> Enum.group_by(fn rel -> rel.relationship_type.label end)
    |> Enum.map(fn {role, rels} ->
      {role, Enum.map(rels, & &1.object)}
    end)
    |> Enum.sort_by(fn {role, _} -> role end)
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end
end
