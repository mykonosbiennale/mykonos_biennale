defmodule MykonosBiennaleWeb.ArtworkController do
  use MykonosBiennaleWeb, :controller

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  def show(conn, %{"id" => id}) do
    case Repo.get(Entity, id) do
      %Entity{type: "artwork", visible: true} = artwork ->
        render_artwork(conn, artwork)

      _ ->
        not_found(conn)
    end
  end

  def show_by_slug(conn, %{"slug" => slug}) do
    case Repo.get_by(Entity, slug: slug, type: "artwork") do
      %Entity{visible: true} = artwork ->
        render_artwork(conn, artwork)

      _ ->
        not_found(conn)
    end
  end

  defp render_artwork(conn, artwork) do
    media = Content.list_media_for_entity(artwork)
    participants = list_linked_participants(artwork)
    events = list_linked_events(artwork)

    conn
    |> assign(:artwork, artwork)
    |> assign(:media, media)
    |> assign(:participants, participants)
    |> assign(:events, events)
    |> assign(:page_title, "#{artwork.fields["title"] || "Untitled"} — Mykonos Biennale")
    |> render(:show)
  end

  defp list_linked_participants(artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^artwork.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
      |> Enum.map(& &1.object)
    else
      []
    end
  end

  defp list_linked_events(artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^artwork.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
      |> Enum.map(fn rel ->
        event = rel.object
        %{
          id: event.id,
          title: event.fields["title"],
          type: event.fields["type"],
          date: event.fields["date"],
          slug: event.slug,
          biennale: biennale_for_event(event)
        }
      end)
    else
      []
    end
  end

  defp biennale_for_event(event) do
    rt = Repo.get_by(RelationshipType, slug: "biennale_event")

    if rt do
      case Repo.one(
             from r in Relationship,
               where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
               preload: [:object]
           ) do
        nil -> nil
        rel -> rel.object
      end
    else
      nil
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end
end
