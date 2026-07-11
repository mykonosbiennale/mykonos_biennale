defmodule MykonosBiennaleWeb.ParticipantController do
  use MykonosBiennaleWeb, :controller

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  def show(conn, %{"id" => id}) do
    case Repo.get(Entity, id) do
      %Entity{type: "participant", visible: true} = participant ->
        render_participant(conn, participant)

      _ ->
        not_found(conn)
    end
  end

  def show_by_slug(conn, %{"slug" => slug}) do
    case Repo.get_by(Entity, slug: slug, type: "participant") do
      %Entity{visible: true} = participant ->
        render_participant(conn, participant)

      _ ->
        not_found(conn)
    end
  end

  defp render_participant(conn, participant) do
    headshot = get_headshot(participant)
    artworks = list_artworks(participant)

    conn
    |> assign(:participant, participant)
    |> assign(:headshot, headshot)
    |> assign(:artworks, artworks)
    |> assign(:page_title, "#{participant_name(participant)} — Mykonos Biennale")
    |> render(:show)
  end

  defp get_headshot(participant) do
    links = Content.list_entity_media_links_for_entity(participant)

    Enum.find_value(links, fn link ->
      if link.metadata && link.metadata["role"] == "headshot", do: link.media
    end)
  end

  defp list_artworks(participant) do
    rels = Content.list_participant_linked_artworks(participant)

    rels
    |> Enum.map(fn rel -> rel.subject end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn a -> a.fields["date"] || "" end, :desc)
    |> Enum.map(fn artwork ->
      media = Content.list_media_for_entity(artwork)
      events = list_artwork_events(artwork)
      {artwork, media, events}
    end)
  end

  defp list_artwork_events(artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

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

  defp participant_name(%Entity{fields: %{"name" => name}}) when is_binary(name) and name != "",
    do: name

  defp participant_name(%Entity{fields: %{"first_name" => first, "last_name" => last}}),
    do: String.trim("#{first || ""} #{last || ""}")

  defp participant_name(_), do: "Unknown"

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end
end
