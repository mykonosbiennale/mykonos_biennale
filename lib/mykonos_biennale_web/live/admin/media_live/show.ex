defmodule MykonosBiennaleWeb.Admin.MediaLive.Show do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Media, Entity, EntityMedia}
  alias MykonosBiennale.Workers.MediaProcess

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    media = Content.get_media!(id)
    linked_entities = get_linked_entities(media)

    {:noreply,
     socket
     |> assign(:page_title, media.caption || "Media ##{media.id}")
     |> assign(:media, media)
     |> assign(:linked_entities, linked_entities)}
  end

  defp get_linked_entities(media) do
    Repo.all(
      from em in EntityMedia,
        where: em.media_id == ^media.id,
        join: e in Entity,
        on: e.id == em.entity_id,
        select: e
    )
    |> Enum.sort_by(fn e ->
      case e.type do
        "participant" -> {0, e.fields["last_name"] || "", e.fields["first_name"] || ""}
        "artwork" -> {1, e.fields["title"] || ""}
        "event" -> {2, e.fields["title"] || ""}
        _ -> {3, ""}
      end
    end)
  end

  defp entity_display_name(%Entity{type: "participant", fields: fields}) do
    first = fields["first_name"] || ""
    last = fields["last_name"] || ""
    "#{first} #{last}" |> String.trim()
  end

  defp entity_display_name(%Entity{fields: fields}), do: fields["title"] || "Untitled"
  defp entity_link(%Entity{type: "participant"} = e), do: "/admin/participants/#{e.id}"
  defp entity_link(%Entity{type: "artwork"} = e), do: "/admin/artworks/#{e.id}"
  defp entity_link(%Entity{type: "event"} = e), do: "/admin/events/#{e.id}"
  defp entity_link(%Entity{type: "biennale"} = e), do: "/admin/biennales/#{e.id}"
  defp entity_link(%Entity{type: "project"} = e), do: "/admin/projects/#{e.id}"
  defp entity_link(%Entity{}), do: "/admin"

  defp media_source_url(%Media{source_type: "upload"} = media),
    do: MykonosBiennale.Uploads.media_url(media, size: "hero")

  defp media_source_url(%Media{source_type: "url", source_url: url}) when is_binary(url), do: url
  defp media_source_url(_), do: nil

  @impl true
  def handle_event("rotate_media", %{"degrees" => degrees}, socket) do
    media = socket.assigns.media
    MediaProcess.enqueue_rotate(media.id, String.to_integer(degrees))

    {:noreply,
     put_flash(
       socket,
       :info,
       "Rotation #{degrees}° queued for #{media.original_name || media.caption}"
     )}
  end
end
