defmodule MykonosBiennaleWeb.Admin.FilmLive.Show do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:active_tab, "default")}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    film = Content.Film.get_for_show!(id)
    relationships = Content.Film.list_relationships(film)
    media = Content.list_media_for_entity(film)
    poster = get_poster(film)

    event_rels =
      Enum.filter(relationships, fn r -> r.relationship_type.slug == "screened_at" end)

    {:noreply,
     socket
     |> assign(:page_title, film.identity || "Film ##{film.id}")
     |> assign(:film, film)
     |> assign(:relationships, relationships)
     |> assign(:event_rels, event_rels)
     |> assign(:media, media)
     |> assign(:poster, poster)}
  end

  defp get_poster(film) do
    alias MykonosBiennale.Content.{Media, EntityMedia}

    Repo.one(
      from em in EntityMedia,
        where: em.entity_id == ^film.id,
        join: m in Media,
        on: m.id == em.media_id,
        where:
          fragment(
            "? ->> 'is_poster' = 'true' or ? ->> 'role' = 'poster'",
            em.metadata,
            em.metadata
          ),
        limit: 1,
        select: %{
          source_type: m.source_type,
          source_path: m.source_path,
          source_url: m.source_url
        }
    )
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("delete", _params, socket) do
    film = socket.assigns.film
    {:ok, _} = Content.Film.delete(film)

    {:noreply, push_navigate(socket, to: "/admin/films")}
  end

  @impl true

  def handle_info({:fields_changed, %{content: content}}, socket) do
    case Jason.decode(content) do
      {:ok, new_fields} ->
        film = socket.assigns.film
        film |> Ecto.Changeset.change(fields: new_fields) |> Repo.update!()
        {:noreply, assign(socket, :film, %{film | fields: new_fields})}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp field(entity, key, default \\ nil)

  defp field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Entity{}, _key, default), do: default

  defp orig_field(film, key) do
    case film.fields["original_record"] do
      %{"fields" => orig} -> Map.get(orig, key)
      _ -> nil
    end
  end
end
