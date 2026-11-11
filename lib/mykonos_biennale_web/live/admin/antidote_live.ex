defmodule MykonosBiennaleWeb.Admin.AntidoteLive do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.{Antidote, Content, Repo, Settings, Uploads}
  alias MykonosBiennale.Content.Entity

  @max_upload_bytes 25_000_000

  @impl true
  def mount(_params, _session, socket) do
    year = Settings.current_biennale_year()

    {:ok,
     socket
     |> assign(:page_title, "Quick Antidote")
     |> assign(:years, years())
     |> assign(:year, year)
     |> assign(:event, antidote_event(year))
     |> assign(:artist_query, "")
     |> assign(:artist_results, [])
     |> assign(:artist_form, blank_artist())
     |> assign(:artwork_form, %{"title" => "", "description" => ""})
     |> assign(:step, :form)
     |> assign(:review, nil)
     |> assign(:selected_media_ids, [])
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .webp .gif),
       max_entries: 30,
       max_file_size: @max_upload_bytes
     )}
  end

  @impl true
  def handle_event("select_year", %{"year" => year}, socket) do
    year = String.to_integer(year)

    {:noreply,
     socket
     |> assign(:year, year)
     |> assign(:event, antidote_event(year))}
  end

  def handle_event("search_artist", %{"q" => q}, socket) do
    q = String.trim(q)

    results =
      if String.length(q) >= 2 do
        Repo.all(
          from e in Entity,
            where: e.type == "participant" and ilike(e.identity, ^"%#{q}%"),
            order_by: e.identity,
            limit: 10
        )
      else
        []
      end

    {:noreply, socket |> assign(:artist_query, q) |> assign(:artist_results, results)}
  end

  def handle_event("pick_artist", %{"id" => id}, socket) do
    participant = Content.get_participant!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:artist_form, artist_from_entity(participant))
     |> assign(:artist_query, "")
     |> assign(:artist_results, [])}
  end

  def handle_event("new_artist", _params, socket) do
    {:noreply, assign(socket, :artist_form, blank_artist())}
  end

  def handle_event("validate", params, socket) do
    {:noreply,
     socket
     |> assign(:artist_form, Map.merge(socket.assigns.artist_form, params["artist"] || %{}))
     |> assign(:artwork_form, Map.merge(socket.assigns.artwork_form, params["artwork"] || %{}))}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  def handle_event("save", params, socket) do
    event = socket.assigns.event

    cond do
      is_nil(event) ->
        {:noreply,
         put_flash(socket, :error, "No Antidote event found for #{socket.assigns.year}.")}

      true ->
        artist = Map.merge(socket.assigns.artist_form, params["artist"] || %{})
        artwork = Map.merge(socket.assigns.artwork_form, params["artwork"] || %{})

        uploads =
          consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
            ext = Path.extname(entry.client_name)
            filename = "#{Ecto.UUID.generate()}#{ext}"
            Uploads.ensure_uploads_dir()
            File.cp!(path, Uploads.uploads_path(filename))

            {:ok,
             %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
          end)

        case Antidote.save_work(event, artist, artwork, uploads) do
          {:ok, result} ->
            review = %{
              event: event,
              participant: result.participant,
              artwork: result.artwork,
              media: result.media
            }

            {:noreply,
             socket
             |> assign(:review, review)
             |> assign(:step, :review)
             |> assign(:selected_media_ids, Enum.map(result.media, & &1.id))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Nothing was saved: #{inspect(reason)}")}
        end
    end
  end

  def handle_event("toggle_media", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected_media_ids

    selected =
      if id in selected, do: List.delete(selected, id), else: selected ++ [id]

    {:noreply, assign(socket, :selected_media_ids, selected)}
  end

  def handle_event("add_to_artboard", _params, socket) do
    %{review: review, selected_media_ids: selected} = socket.assigns

    case Antidote.add_to_artboard(review.event, selected) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added #{length(selected)} image(s) to the art board.")
         |> reset_form()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update the art board.")}
    end
  end

  def handle_event("new_work", _params, socket) do
    {:noreply, reset_form(socket)}
  end

  defp reset_form(socket) do
    socket
    |> assign(:artist_form, blank_artist())
    |> assign(:artwork_form, %{"title" => "", "description" => ""})
    |> assign(:step, :form)
    |> assign(:review, nil)
    |> assign(:selected_media_ids, [])
  end

  defp years do
    Content.list_biennales()
    |> Enum.map(&parse_year(&1.fields["year"]))
    |> Enum.sort(:desc)
  end

  defp parse_year(year) when is_integer(year), do: year
  defp parse_year(year), do: String.to_integer(to_string(year))

  @antidote_project_id 30

  defp antidote_event(year) do
    Content.list_events_for_biennale(year)
    |> Enum.find(&(&1.fields["type"] == "exhibition" and in_antidote_project?(&1)))
  end

  defp in_antidote_project?(event) do
    Repo.exists?(
      from r in MykonosBiennale.Content.Relationship,
        join: rt in MykonosBiennale.Content.RelationshipType,
        on: rt.id == r.relationship_type_id,
        where:
          rt.slug == "event_project" and r.subject_id == ^event.id and
            r.object_id == ^@antidote_project_id
    )
  end

  defp blank_artist,
    do: %{"id" => "", "first_name" => "", "last_name" => "", "bio" => "", "statement" => ""}

  defp artist_from_entity(%Entity{} = e) do
    %{
      "id" => to_string(e.id),
      "first_name" => e.fields["first_name"] || "",
      "last_name" => e.fields["last_name"] || "",
      "bio" => e.fields["bio"] || "",
      "statement" => e.fields["statement"] || ""
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto px-4 py-8 space-y-8">
        <h1 class="text-xl font-bold text-white">Quick Antidote</h1>

        <%= if @step == :form do %>
          <section class="space-y-3">
            <h2 class="text-sm font-semibold uppercase text-gray-400">1. Year and event</h2>
            <div class="flex flex-wrap gap-3 items-center">
              <form phx-change="select_year">
                <select
                  name="year"
                  class="bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
                >
                  <option :for={y <- @years} value={y} selected={y == @year}>{y}</option>
                </select>
              </form>
              <p :if={@event} class="text-gray-200">
                Event: <span class="text-white">{@event.fields["title"]}</span>
              </p>
              <p :if={!@event} class="text-red-400">
                No Antidote event for {@year}. Add one in Events first.
              </p>
            </div>
          </section>

          <section class="space-y-3">
            <h2 class="text-sm font-semibold uppercase text-gray-400">2. Artist</h2>
            <form phx-change="search_artist" class="flex gap-2">
              <input
                type="text"
                name="q"
                value={@artist_query}
                placeholder="Search existing artists…"
                phx-debounce="300"
                class="flex-1 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              />
              <button
                type="button"
                phx-click="new_artist"
                class="px-3 py-2 bg-gray-700 text-white rounded"
              >
                New artist
              </button>
            </form>
            <ul
              :if={@artist_results != []}
              class="bg-gray-900 border border-gray-800 rounded divide-y divide-gray-800"
            >
              <li :for={p <- @artist_results}>
                <button
                  type="button"
                  phx-click="pick_artist"
                  phx-value-id={p.id}
                  class="w-full text-left px-3 py-2 text-gray-200 hover:bg-gray-800"
                >
                  {p.identity}
                </button>
              </li>
            </ul>
          </section>

          <form id="antidote-form" phx-change="validate" phx-submit="save" class="space-y-6">
            <section class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <input type="hidden" name="artist[id]" value={@artist_form["id"]} />
              <input
                type="text"
                name="artist[first_name]"
                value={@artist_form["first_name"]}
                placeholder="First name"
                class="bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              />
              <input
                type="text"
                name="artist[last_name]"
                value={@artist_form["last_name"]}
                placeholder="Last name"
                class="bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              />
              <textarea
                name="artist[bio]"
                placeholder="Bio"
                rows="3"
                class="md:col-span-2 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              >{@artist_form["bio"]}</textarea>
              <textarea
                name="artist[statement]"
                placeholder="Statement"
                rows="3"
                class="md:col-span-2 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              >{@artist_form["statement"]}</textarea>
            </section>

            <section class="space-y-3">
              <h2 class="text-sm font-semibold uppercase text-gray-400">3. Artwork</h2>
              <input
                type="text"
                name="artwork[title]"
                value={@artwork_form["title"]}
                placeholder="Artwork title"
                class="w-full bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              />
              <textarea
                name="artwork[description]"
                placeholder="Description"
                rows="2"
                class="w-full bg-gray-800 border border-gray-700 rounded px-3 py-2 text-white"
              >{@artwork_form["description"]}</textarea>

              <div
                phx-drop-target={@uploads.images.ref}
                class="border border-dashed border-gray-700 rounded p-4 text-gray-400"
              >
                <.live_file_input upload={@uploads.images} class="text-sm" />
                <div
                  :for={entry <- @uploads.images.entries}
                  class="flex items-center gap-2 mt-2 text-sm"
                >
                  <span>{entry.client_name}</span>
                  <progress value={entry.progress} max="100">{entry.progress}%</progress>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="text-red-400"
                  >
                    remove
                  </button>
                </div>
              </div>
            </section>

            <button
              type="submit"
              class="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded"
            >
              Save artist and artwork
            </button>
          </form>
        <% else %>
          <section class="space-y-2 text-gray-300">
            <h2 class="text-sm font-semibold uppercase text-gray-400">4. Review</h2>
            <p>Artist: <span class="text-white">{@review.participant.identity}</span></p>
            <p>Artwork: <span class="text-white">{@review.artwork.identity}</span></p>
            <p>Event: <span class="text-white">{@review.event.fields["title"]}</span></p>
            <p>Links: artist → artwork (artist), artwork → event</p>
          </section>

          <section class="space-y-3">
            <h2 class="text-sm font-semibold uppercase text-gray-400">
              Choose images for the art board
            </h2>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              <button
                :for={m <- @review.media}
                type="button"
                phx-click="toggle_media"
                phx-value-id={m.id}
                class={[
                  "relative aspect-square rounded overflow-hidden border-2",
                  if(m.id in @selected_media_ids, do: "border-purple-500", else: "border-gray-800")
                ]}
              >
                <img src={Uploads.media_url(m, size: "thumb")} class="w-full h-full object-cover" />
                <span
                  :if={m.id in @selected_media_ids}
                  class="absolute top-1 right-1 bg-purple-600 text-white text-xs px-1 rounded"
                >
                  selected
                </span>
              </button>
            </div>
            <div class="flex gap-3">
              <button
                type="button"
                phx-click="add_to_artboard"
                class="px-4 py-2 bg-purple-600 text-white rounded"
              >
                Add selected to art board
              </button>
              <button
                type="button"
                phx-click="new_work"
                class="px-4 py-2 bg-gray-700 text-white rounded"
              >
                Done, add another
              </button>
            </div>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
