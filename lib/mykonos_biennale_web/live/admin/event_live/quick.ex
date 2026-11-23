defmodule MykonosBiennaleWeb.Admin.EventLive.Quick do
  @moduledoc """
  Quick event form (issue #288).

  Step 1 (`:new`) asks for a category (art show, screening or event) and the basic
  details, then creates the event. Step 2 (`:edit`) fills it in: an art board for art
  shows, or attached media with shared captions for screenings and events.

  The full event form stays available from the edit page.
  """
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.EventCategory
  alias MykonosBiennale.Uploads
  alias MykonosBiennale.Workers.MediaProcess

  @page_size 200

  @rotate_options [
    {"No rotation", ""},
    {"Rotate 90°", "90"},
    {"Rotate 180°", "180"},
    {"Rotate 270°", "270"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, 0)
     |> assign(:rotate_options, @rotate_options)
     |> assign(:biennales, Content.list_biennales())
     |> assign(:category_options, Enum.map(EventCategory.all(), &{&1.label, &1.key}))
     |> assign(:event_type_options, event_type_options())
     |> assign(:form, new_form())
     |> assign(:pending_reindex, [])
     |> allow_upload(:media,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 200,
       max_file_size: 20_000_000,
       auto_upload: true,
       progress: &handle_upload_progress/3
     )}
  end

  @impl true
  def handle_params(_params, _url, %{assigns: %{live_action: :new}} = socket) do
    events = Content.list_events()
    years = events |> Enum.map(& &1.id) |> Content.event_years()

    {:noreply,
     socket
     |> assign(:page_title, "Quick Event")
     |> assign(:event, nil)
     |> assign(:category, nil)
     |> assign(:event_options, Enum.map(events, &{Content.event_label(&1, years), &1.id}))}
  end

  def handle_params(%{"id" => id} = params, _url, %{assigns: %{live_action: :edit}} = socket) do
    event = Content.get_event!(id)
    category = EventCategory.key_for_type(event.fields["type"]) || "event"

    {:noreply,
     socket
     |> assign(:page_title, "Quick Event")
     |> assign(:event, event)
     |> assign(:category, category)
     |> assign(:page, page_param(params))
     |> load_step()}
  end

  # Step 1: create the event

  @impl true
  def handle_event("open_existing", %{"event_id" => ""}, socket) do
    {:noreply, put_flash(socket, :error, "Choose an event")}
  end

  def handle_event("open_existing", %{"event_id" => event_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/events/quick/#{event_id}")}
  end

  def handle_event("validate", %{"quick" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :quick))}
  end

  def handle_event("create", %{"quick" => params}, socket) do
    title = blank_to_nil(params["title"]) |> then(&(&1 && String.trim(&1)))
    biennale_id = to_id(params["biennale_id"])

    cond do
      is_nil(title) ->
        {:noreply,
         socket
         |> put_flash(:error, "Enter a title")
         |> assign(:form, to_form(params, as: :quick))}

      is_nil(biennale_id) ->
        {:noreply,
         socket
         |> put_flash(:error, "Choose a biennale")
         |> assign(:form, to_form(params, as: :quick))}

      true ->
        attrs =
          %{
            title: title,
            type: stored_type(params),
            biennale_id: biennale_id,
            date: parse_date(params["date"]),
            time: blank_to_nil(params["time"]),
            location: blank_to_nil(params["location"]),
            description: blank_to_nil(params["description"])
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        case Content.create_event(attrs) do
          {:ok, event} ->
            {:noreply,
             socket
             |> put_flash(:info, "Event created. Now add the media.")
             |> push_patch(to: ~p"/admin/events/quick/#{event.id}")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not create the event")
             |> assign(:form, to_form(params, as: :quick))}
        end
    end
  end

  # Step 2: art board (art shows)

  def handle_event("toggle_artboard", %{"media-id" => media_id}, socket) do
    media_id = String.to_integer(media_id)
    current = Enum.map(socket.assigns.artboard_selected, & &1.id)

    new_ids =
      if media_id in current,
        do: List.delete(current, media_id),
        else: current ++ [media_id]

    case Content.update_event(socket.assigns.event, %{artboard_media_ids: new_ids}) do
      {:ok, event} ->
        {:noreply, socket |> assign(:event, event) |> load_step()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update the art board")}
    end
  end

  # Step 2: media (screenings and events)

  def handle_event("attach_media", %{"media_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("attach_media", %{"media_id" => media_id}, socket) do
    media = Content.get_media!(media_id)

    case Content.attach_media_to_entity(socket.assigns.event, media) do
      {:ok, :attached} -> {:noreply, load_step(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, to_string(reason))}
    end
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    media = Content.get_media!(media_id)
    {:ok, _} = Content.detach_media_from_entity(socket.assigns.event, media)
    {:noreply, load_step(socket)}
  end

  # Saves the current page of the media grid: captions, rotations and removals.
  # The nav button (save, previous, next) decides which page is shown afterwards.
  def handle_event("save_grid", params, socket) do
    event = socket.assigns.event

    summary =
      Enum.reduce(
        socket.assigns.attached,
        %{captions: 0, rotations: 0, removed: 0, errors: 0},
        &save_grid_row(&1, event, params, &2)
      )

    target = nav_page(params["nav"], socket.assigns.page, socket.assigns.page_count)
    level = if summary.errors > 0, do: :error, else: :info

    {:noreply,
     socket
     |> put_flash(level, grid_message(summary))
     |> push_patch(to: ~p"/admin/events/quick/#{event.id}?page=#{target + 1}")}
  end

  # Step 2: uploads (each file becomes a media record as soon as it has uploaded)

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  def handle_upload_progress(:media, entry, socket) do
    if entry.done? do
      {:noreply, socket |> save_uploaded_media(entry) |> finish_batch_if_idle()}
    else
      {:noreply, socket}
    end
  end

  # Runs once every selected file has finished uploading. The search reindex jobs go in
  # one insert, and the lists reload once, instead of once per file.
  defp finish_batch_if_idle(socket) do
    if Enum.all?(socket.assigns.uploads.media.entries, & &1.done?) do
      case socket.assigns.pending_reindex do
        [] -> :ok
        ids -> Content.enqueue_media_reindex(ids)
      end

      socket
      |> assign(:pending_reindex, [])
      |> load_step()
    else
      socket
    end
  end

  defp save_uploaded_media(socket, entry) do
    caption = socket.assigns.event.fields["title"]

    case consume_uploaded_entry(socket, entry, fn %{path: path} ->
           {:ok, store_upload(path, entry, caption)}
         end) do
      {:ok, media} -> attach_uploaded(socket, media)
      {:error, _changeset} -> put_flash(socket, :error, "Could not save #{entry.client_name}")
    end
  end

  defp attach_uploaded(socket, media) do
    event = socket.assigns.event
    _ = Content.attach_media_to_entity(event, media, defer_reindex: true)

    socket
    |> assign(:event, add_to_artboard_if_art_show(event, media))
    |> update(:pending_reindex, &[media.id | &1])
  end

  defp add_to_artboard_if_art_show(event, media) do
    if EventCategory.key_for_type(event.fields["type"]) == "art_show" do
      ids = Enum.uniq(artboard_ids(event) ++ [media.id])

      case Content.update_event(event, %{artboard_media_ids: ids}) do
        {:ok, updated} -> updated
        {:error, _} -> event
      end
    else
      event
    end
  end

  defp store_upload(path, entry, caption) do
    ext = Path.extname(entry.client_name)
    filename = "#{Ecto.UUID.generate()}#{ext}"
    dest = Uploads.uploads_path(filename)

    Uploads.ensure_uploads_dir()
    File.cp!(path, dest)

    Content.create_media(
      %{
        source_type: "upload",
        source_path: filename,
        mime_type: entry.client_type,
        original_name: entry.client_name,
        caption: caption
      },
      defer_reindex: true
    )
  end

  # Loading

  defp load_step(%{assigns: %{category: "art_show", event: event}} = socket) do
    pool = Content.list_event_artwork_media(event)
    pool_media = Enum.uniq_by(pool, & &1.media.id)

    selected_ids = artboard_ids(event)

    by_id = Map.new(Content.get_media_by_ids(selected_ids), &{&1.id, &1})
    selected = Enum.flat_map(selected_ids, fn id -> List.wrap(Map.get(by_id, id)) end)

    available = Enum.reject(pool_media, &(&1.media.id in selected_ids))

    socket
    |> assign(:artboard_selected, selected)
    |> assign(:artboard_pool, available)
    |> assign(:attached, [])
    |> assign(:available_media, [])
  end

  defp load_step(%{assigns: %{event: event}} = socket) do
    all_attached = Content.list_media_for_entity(event)
    attached_ids = MapSet.new(all_attached, & &1.id)
    available = Enum.reject(Content.list_media(), &MapSet.member?(attached_ids, &1.id))

    total = length(all_attached)
    page_count = max(ceil(total / @page_size), 1)
    page = min(socket.assigns.page, page_count - 1)

    socket
    |> assign(:artboard_selected, [])
    |> assign(:artboard_pool, [])
    |> assign(:attached, Enum.slice(all_attached, page * @page_size, @page_size))
    |> assign(:attached_total, total)
    |> assign(:page, page)
    |> assign(:page_count, page_count)
    |> assign(:available_media, available)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6">
          <.link navigate={~p"/admin/events"} class="text-gray-400 hover:text-white text-sm">
            ← Back to Events
          </.link>
        </div>

        <%= if @live_action == :new do %>
          <h1 class="text-2xl font-semibold text-white mb-6">Quick event</h1>

          <div class="bg-gray-800/40 rounded-xl p-6 mb-6">
            <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-4">
              Continue an existing event
            </h2>
            <form id="open-existing-form" phx-submit="open_existing" class="flex gap-2">
              <select
                name="event_id"
                class="flex-1 rounded-lg border-gray-600 bg-gray-900 text-white text-sm"
              >
                <option value="">Choose an event…</option>
                <option :for={{label, id} <- @event_options} value={id}>{label}</option>
              </select>
              <button type="submit" class="btn btn-primary">Continue</button>
            </form>
          </div>

          <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-4">
            Or create a new event
          </h2>

          <.form for={@form} id="quick-event-form" phx-change="validate" phx-submit="create">
            <div class="bg-white rounded-xl p-6 space-y-4 text-gray-900">
              <.input
                field={@form[:category]}
                type="select"
                label="Category"
                options={@category_options}
              />

              <%= if @form[:category].value == "event" do %>
                <.input
                  field={@form[:type]}
                  type="select"
                  label="Kind of event"
                  options={@event_type_options}
                />
              <% end %>

              <.input field={@form[:title]} type="text" label="Title" required />

              <.input
                field={@form[:biennale_id]}
                type="select"
                label="Biennale"
                prompt="Choose a biennale"
                options={Enum.map(@biennales, &{biennale_year(&1), &1.id})}
              />

              <.input field={@form[:date]} type="date" label="Date" />

              <%= if @form[:category].value == "event" do %>
                <.input field={@form[:time]} type="time" label="Time" />
                <.input field={@form[:location]} type="text" label="Location" />
                <.input field={@form[:description]} type="textarea" label="Description" rows="4" />
              <% end %>

              <div class="flex justify-end">
                <button type="submit" phx-disable-with="Creating..." class="btn btn-primary">
                  Create and add media
                </button>
              </div>
            </div>
          </.form>
        <% else %>
          <div class="flex items-start justify-between gap-4 mb-6">
            <div>
              <h1 class="text-2xl font-semibold text-white">
                {title_of(@event)}
              </h1>
              <p class="text-sm text-gray-400 mt-1">
                {EventCategory.type_label(@event.fields["type"])} · {@event.fields["date"] ||
                  "No date"}
              </p>
            </div>
            <div class="flex gap-4 text-sm whitespace-nowrap">
              <.link
                href={~p"/event/#{@event.id}"}
                target="_blank"
                class="text-blue-400 hover:text-blue-300"
              >
                See on site
              </.link>
              <.link
                navigate={~p"/admin/events/#{@event.id}/edit"}
                class="text-gray-300 hover:text-white"
              >
                Full edit form
              </.link>
            </div>
          </div>

          <.upload_box uploads={@uploads} />

          <%= if @category == "art_show" do %>
            <section class="space-y-6">
              <div class="bg-gray-800/40 rounded-xl p-6">
                <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-4">
                  Art board ({length(@artboard_selected)})
                </h2>
                <%= if @artboard_selected == [] do %>
                  <p class="text-sm text-gray-500">No artworks on the art board yet.</p>
                <% else %>
                  <div class="grid grid-cols-3 sm:grid-cols-4 gap-4">
                    <div :for={media <- @artboard_selected} class="space-y-2">
                      <div class="aspect-square bg-gray-900 rounded-lg overflow-hidden">
                        <img
                          :if={thumb(media)}
                          src={thumb(media)}
                          alt={media_label(media)}
                          class="w-full h-full object-cover"
                        />
                      </div>
                      <button
                        type="button"
                        phx-click="toggle_artboard"
                        phx-value-media-id={media.id}
                        class="text-xs text-red-400 hover:text-red-300"
                      >
                        Remove
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="bg-gray-800/40 rounded-xl p-6">
                <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-4">
                  Artworks linked to this event
                </h2>
                <%= if @artboard_pool == [] do %>
                  <p class="text-sm text-gray-500">
                    No artwork media. Link artworks to this event first.
                  </p>
                <% else %>
                  <div class="grid grid-cols-3 sm:grid-cols-4 gap-4">
                    <div :for={%{media: media, artwork: artwork} <- @artboard_pool} class="space-y-2">
                      <div class="aspect-square bg-gray-900 rounded-lg overflow-hidden">
                        <img
                          :if={thumb(media)}
                          src={thumb(media)}
                          alt={title_of(artwork)}
                          class="w-full h-full object-cover"
                        />
                      </div>
                      <p class="text-xs text-gray-400 truncate">{title_of(artwork)}</p>
                      <button
                        type="button"
                        phx-click="toggle_artboard"
                        phx-value-media-id={media.id}
                        class="text-xs text-purple-400 hover:text-purple-300"
                      >
                        Add to art board
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </section>
          <% else %>
            <section class="space-y-6">
              <div class="bg-gray-800/40 rounded-xl p-6">
                <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-2">
                  Media ({@attached_total})
                </h2>
                <p class="text-xs text-gray-500 mb-4">
                  Captions are stored on the media, so an edit shows on every event that uses it.
                  Rotations and removals apply when you save.
                </p>
                <%= if @attached_total == 0 do %>
                  <p class="text-sm text-gray-500">No media attached yet.</p>
                <% else %>
                  <form id="media-grid" phx-submit="save_grid" class="space-y-3">
                    <%!-- Hidden default button: pressing Enter in a caption saves and stays. --%>
                    <button type="submit" name="nav" value="stay" class="hidden" tabindex="-1">
                      Save
                    </button>
                    <.pager page={@page} page_count={@page_count} total={@attached_total} />
                    <div class="divide-y divide-gray-700">
                      <.media_row
                        :for={media <- @attached}
                        media={media}
                        rotate_options={@rotate_options}
                      />
                    </div>
                    <.pager page={@page} page_count={@page_count} total={@attached_total} />
                  </form>
                <% end %>
              </div>

              <div class="bg-gray-800/40 rounded-xl p-6">
                <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-4">
                  Add media
                </h2>
                <form phx-submit="attach_media" class="flex gap-2">
                  <select
                    name="media_id"
                    class="flex-1 rounded-lg border-gray-600 bg-gray-900 text-white text-sm"
                  >
                    <option value="">Choose media…</option>
                    <option :for={media <- @available_media} value={media.id}>
                      {media_label(media)}
                    </option>
                  </select>
                  <button type="submit" class="btn btn-primary">Attach</button>
                </form>
              </div>
            </section>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :page, :integer, required: true
  attr :page_count, :integer, required: true
  attr :total, :integer, required: true

  defp pager(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-between gap-3 text-sm">
      <div class="flex gap-2">
        <button
          type="submit"
          name="nav"
          value="prev"
          disabled={@page == 0}
          class="rounded-lg bg-gray-700 px-3 py-1.5 text-white hover:bg-gray-600 disabled:opacity-40"
        >
          ← Save and previous
        </button>
        <button
          type="submit"
          name="nav"
          value="next"
          disabled={@page + 1 >= @page_count}
          class="rounded-lg bg-gray-700 px-3 py-1.5 text-white hover:bg-gray-600 disabled:opacity-40"
        >
          Save and next →
        </button>
      </div>
      <span class="text-gray-400">
        Page {@page + 1} of {@page_count} · {@total} items
      </span>
      <button type="submit" name="nav" value="stay" class="btn btn-primary">Save</button>
    </div>
    """
  end

  attr :media, :map, required: true
  attr :rotate_options, :list, required: true

  defp media_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-2">
      <div class="h-16 w-16 shrink-0 overflow-hidden rounded bg-gray-900">
        <img
          :if={thumb(@media)}
          src={thumb(@media)}
          alt=""
          loading="lazy"
          class="h-full w-full object-cover"
        />
      </div>
      <input
        type="text"
        name={"captions[#{@media.id}]"}
        value={@media.caption}
        placeholder="Caption"
        class="flex-1 rounded-lg border-gray-600 bg-gray-900 text-sm text-white"
      />
      <select
        name={"rotate[#{@media.id}]"}
        class="rounded-lg border-gray-600 bg-gray-900 text-sm text-white"
      >
        <option :for={{label, value} <- @rotate_options} value={value}>{label}</option>
      </select>
      <label class="flex items-center gap-1.5 whitespace-nowrap text-xs text-red-400">
        <input
          type="checkbox"
          name={"delete[#{@media.id}]"}
          value="true"
          class="rounded border-gray-600 bg-gray-900"
        /> Remove
      </label>
    </div>
    """
  end

  defp upload_box(assigns) do
    ~H"""
    <div class="bg-gray-800/40 rounded-xl p-6 mb-6">
      <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-300 mb-2">
        Upload images
      </h2>
      <p class="text-xs text-gray-500 mb-4">
        Select one or several images. Each becomes a media record as soon as it has uploaded.
      </p>
      <form id="quick-upload-form" phx-change="validate_upload" class="space-y-3">
        <.live_file_input upload={@uploads.media} class="text-sm text-gray-300" />
        <div
          :for={entry <- @uploads.media.entries}
          class="flex items-center gap-3 text-xs text-gray-300"
        >
          <span class="truncate flex-1">{entry.client_name}</span>
          <progress value={entry.progress} max="100" class="w-32">{entry.progress}%</progress>
          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-ref={entry.ref}
            class="text-red-400 hover:text-red-300"
          >
            Cancel
          </button>
          <p :for={err <- upload_errors(@uploads.media, entry)} class="text-red-400">
            {upload_error_text(err)}
          </p>
        </div>
        <p :for={err <- upload_errors(@uploads.media)} class="text-sm text-red-400">
          {upload_error_text(err)}
        </p>
      </form>
    </div>
    """
  end

  defp upload_error_text(:too_large), do: "File is too large"
  defp upload_error_text(:not_accepted), do: "File type not accepted"
  defp upload_error_text(:too_many_files), do: "Too many files selected"
  defp upload_error_text(err), do: "Upload error: #{inspect(err)}"

  # Helpers

  defp new_form do
    to_form(
      %{"category" => "art_show", "type" => "event", "biennale_id" => "", "date" => ""},
      as: :quick
    )
  end

  defp event_type_options do
    Enum.map(EventCategory.types("event"), &{EventCategory.type_label(&1), &1})
  end

  defp stored_type(%{"category" => "art_show"}), do: "exhibition"
  defp stored_type(%{"category" => "screening"}), do: "screening"

  defp stored_type(%{"category" => "event", "type" => type}) do
    if type in EventCategory.types("event"), do: type, else: "event"
  end

  defp stored_type(_), do: "event"

  defp artboard_ids(event) do
    event.fields
    |> Map.get("artboard_media_ids", [])
    |> Enum.map(fn id -> if is_binary(id), do: String.to_integer(id), else: id end)
  end

  defp thumb(%{source_type: "upload", source_path: path} = media) when is_binary(path),
    do: Uploads.media_url(media, size: "thumb")

  defp thumb(%{source_url: url}) when is_binary(url), do: url
  defp thumb(_media), do: nil

  defp title_of(%Entity{fields: fields, identity: identity}),
    do: fields["title"] || identity || "Untitled"

  defp title_of(_), do: "Untitled"

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp to_id(value) when value in [nil, ""], do: nil
  defp to_id(value) when is_integer(value), do: value
  defp to_id(value) when is_binary(value), do: String.to_integer(value)

  defp parse_date(value) do
    case blank_to_nil(value) && Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp page_param(params) do
    case Integer.parse(params["page"] || "") do
      {n, ""} when n >= 1 -> n - 1
      _ -> 0
    end
  end

  defp nav_page("next", page, page_count), do: min(page + 1, page_count - 1)
  defp nav_page("prev", page, _page_count), do: max(page - 1, 0)
  defp nav_page(_nav, page, _page_count), do: page

  defp save_grid_row(media, event, params, acc) do
    id = Integer.to_string(media.id)

    if get_in(params, ["delete", id]) == "true" do
      {:ok, _} = Content.detach_media_from_entity(event, media)
      bump(acc, :removed)
    else
      acc
      |> save_caption_change(media, get_in(params, ["captions", id]))
      |> queue_rotation(media.id, get_in(params, ["rotate", id]))
    end
  end

  defp save_caption_change(acc, _media, nil), do: acc

  defp save_caption_change(acc, media, value) do
    caption = blank_to_nil(value)

    if caption == media.caption do
      acc
    else
      case Content.update_media(media, %{caption: caption}) do
        {:ok, _} -> bump(acc, :captions)
        _ -> bump(acc, :errors)
      end
    end
  end

  defp queue_rotation(acc, media_id, degrees) when degrees in ["90", "180", "270"] do
    case MediaProcess.enqueue_rotate(media_id, String.to_integer(degrees)) do
      {:ok, _job} -> bump(acc, :rotations)
      _ -> bump(acc, :errors)
    end
  end

  defp queue_rotation(acc, _media_id, _degrees), do: acc

  defp bump(acc, key), do: Map.update!(acc, key, &(&1 + 1))

  defp grid_message(%{captions: 0, rotations: 0, removed: 0, errors: 0}),
    do: "No changes to save"

  defp grid_message(%{captions: c, rotations: r, removed: d, errors: e}) do
    "Saved: #{c} caption(s), #{r} rotation(s) queued, #{d} removed" <>
      if(e > 0, do: ", #{e} failed", else: "")
  end

  defp media_label(media), do: media.caption || "#{media.source_type} #{media.id}"

  defp biennale_year(biennale), do: biennale.fields["year"]
end
