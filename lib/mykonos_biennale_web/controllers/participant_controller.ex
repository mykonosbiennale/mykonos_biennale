defmodule MykonosBiennaleWeb.ParticipantController do
  use MykonosBiennaleWeb, :controller

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity

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
    biennale_groups = Content.list_participant_works_by_biennale(participant)

    conn
    |> assign(:participant, participant)
    |> assign(:headshot, headshot)
    |> assign(:biennale_groups, biennale_groups)
    |> assign(:page_title, "#{participant_name(participant)} — Mykonos Biennale")
    |> render(:show)
  end

  defp get_headshot(participant) do
    links = Content.list_entity_media_links_for_entity(participant)

    Enum.find_value(links, fn link ->
      if link.metadata && link.metadata["role"] == "headshot", do: link.media
    end)
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
