defmodule MykonosBiennaleWeb.Admin.EventLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Relationship, Media, Entity}
  alias Ecto.Changeset

  defmodule EventForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :project_id, :integer
      field :title, :string
      field :type, :string
      field :biennale_id, :integer
      field :date, :date
      field :time, :string
      field :location, :string
      field :tickets, :string
      field :description, :string
      field :show_project, :boolean, default: true
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [
        :project_id,
        :title,
        :type,
        :biennale_id,
        :date,
        :time,
        :location,
        :tickets,
        :description,
        :show_project,
        :visible
      ])
      |> validate_required([:title, :type, :biennale_id])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900">
      <.header>
        {@title}
        <:actions>
          <.link
            :if={@event.id}
            href={"/event/#{@event.id}"}
            target="_blank"
            class="text-sm text-blue-600 hover:text-blue-700"
          >
            See on Site
          </.link>
        </:actions>
      </.header>

      <.form
        for={@form}
        id="event-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input
            field={@form[:biennale_id]}
            type="select"
            label="Biennale"
            prompt="Choose a biennale"
            options={Enum.map(@biennales, &{&1.fields["year"], &1.id})}
            required
          />

          <.input
            field={@form[:project_id]}
            type="select"
            label="Project"
            prompt="Choose a project"
            options={Enum.map(@projects, &{&1.fields["title"], &1.id})}
          />

          <.input field={@form[:title]} type="text" label="Title" required />

          <.input
            field={@form[:type]}
            type="select"
            label="Type"
            prompt="Choose an event type"
            options={[
              {"Exhibition", "exhibition"},
              {"Performance", "performance"},
              {"Screening", "screening"},
              {"Workshop", "workshop"},
              {"Celebration", "celebration"},
              {"Event", "event"}
            ]}
            required
          />

          <.input field={@form[:date]} type="date" label="Date" />
          <.input field={@form[:time]} type="time" label="Time" />
          <.input field={@form[:location]} type="text" label="Location" />
          <.input field={@form[:tickets]} type="text" label="Tickets URL" />
          <.input field={@form[:description]} type="textarea" label="Description" rows="5" />
          <.input field={@form[:show_project]} type="checkbox" label="Show all artworks/films from this project" />
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-400 hover:text-white">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Event
          </button>
        </div>
      </.form>

      <%= if @is_screening do %>
        <div class="mt-6">
          <label class="block text-sm font-semibold text-gray-900 dark:text-gray-100 mb-2">
            Attached Media
          </label>

          <%= if @current_media_links == [] do %>
            <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
              No media attached yet
            </p>
          <% else %>
            <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">
              Drag to reorder. Changes are saved immediately.
            </p>

            <div
              id="event-media-links"
              phx-hook="SortableMediaLinks"
              phx-target={@myself}
              class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-4"
            >
              <div
                :for={link <- @current_media_links}
                data-media-id={link.media_id}
                draggable="true"
                class="relative group bg-gray-50 dark:bg-gray-800 rounded-lg overflow-hidden"
              >
                <div class="aspect-video bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
                  <%= case link.media.source_type do %>
                    <% "upload" -> %>
                      <%= if link.media.source_path do %>
                        <img
                          src={MykonosBiennale.Uploads.media_url(link.media, size: "thumb")}
                          alt={link.media.alt_text || link.media.caption}
                          class="w-full h-full object-cover"
                        />
                      <% else %>
                        <.icon name="hero-photo" class="w-8 h-8 text-gray-400" />
                      <% end %>
                    <% "url" -> %>
                      <%= if link.media.source_url do %>
                        <img
                          src={link.media.source_url}
                          alt={link.media.alt_text || link.media.caption}
                          class="w-full h-full object-cover"
                        />
                      <% else %>
                        <.icon name="hero-link" class="w-8 h-8 text-gray-400" />
                      <% end %>
                    <% "embed" -> %>
                      <.icon name="hero-video-camera" class="w-8 h-8 text-gray-400" />
                  <% end %>
                </div>
                <button
                  type="button"
                  phx-click="detach_media"
                  phx-value-media-id={link.media_id}
                  phx-target={@myself}
                  class="absolute top-2 right-2 bg-red-600 text-white p-1 rounded opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>

                <div class="p-2 space-y-2">
                  <div class="text-xs text-gray-600 dark:text-gray-300 truncate">
                    {link.media.caption || "Untitled"}
                  </div>

                  <form phx-change="update_media_link" phx-target={@myself} class="space-y-1">
                    <input type="hidden" name="media_id" value={link.media_id} />
                    <input
                      name="metadata[caption_override]"
                      value={link.metadata["caption_override"] || ""}
                      placeholder="Caption override (optional)"
                      class="w-full text-xs rounded border-gray-300 dark:border-gray-600 bg-white/80 dark:bg-gray-900/50 text-gray-900 dark:text-gray-100 px-2 py-1"
                    />
                    <input
                      name="metadata[alt_override]"
                      value={link.metadata["alt_override"] || ""}
                      placeholder="Alt override (optional)"
                      class="w-full text-xs rounded border-gray-300 dark:border-gray-600 bg-white/80 dark:bg-gray-900/50 text-gray-900 dark:text-gray-100 px-2 py-1"
                    />
                  </form>
                </div>
              </div>
            </div>
          <% end %>

          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Add Media
            </label>
            <form phx-change="attach_media" phx-target={@myself}>
              <select
                name="media_id"
                class="w-full rounded-lg border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
              >
                <option value="">Select media to attach...</option>
                <%= for media <- @available_media do %>
                  <option value={media.id}>
                    {media.caption || "#{media.source_type} - #{media.id}"}
                  </option>
                <% end %>
              </select>
            </form>
          </div>

          <%= if @event.id do %>
            <div class="mt-4 space-y-2">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Upload Images
              </label>
              <.live_file_input upload={@uploads.images} class="hidden" />
              <button
                type="button"
                onclick={"document.getElementById('event-form_images').click()"}
                class="w-full rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600 hover:border-purple-500 px-4 py-6 text-center text-sm text-gray-500 dark:text-gray-400 transition-colors"
              >
                Click to select images
              </button>

              <%= for entry <- @uploads.images.entries do %>
                <div class="flex items-center gap-3 mt-2">
                  <%= if entry.done? do %>
                    <.icon name="hero-check-circle" class="w-5 h-5 text-green-500" />
                  <% else %>
                    <div class="w-5 h-5 rounded-full border-2 border-purple-500 border-t-transparent animate-spin"></div>
                  <% end %>
                  <span class="text-xs text-gray-600 dark:text-gray-300 flex-1 truncate">{entry.client_name}</span>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    phx-target={@myself}
                    class="text-red-500 hover:text-red-700"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% end %>

              <%= if @uploads.images.entries != [] and Enum.all?(@uploads.images.entries, & &1.done?) do %>
                <button
                  type="button"
                  phx-click="save_uploads"
                  phx-target={@myself}
                  class="mt-2 px-4 py-2 bg-purple-600 text-white rounded-lg text-sm font-medium hover:bg-purple-700"
                >
                  Save {length(@uploads.images.entries)} image(s)
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @event.id != nil and not @is_screening do %>
        <div class="mt-6 border-t pt-6">
          <label class="block text-sm font-semibold text-gray-900 mb-2">
            Poster
          </label>

          <%= if @poster_link do %>
            <div class="relative group inline-block">
              <div class="w-48 rounded-lg overflow-hidden border border-gray-200">
                <div class="aspect-video bg-gray-100 flex items-center justify-center">
                  <%= if @poster_link.media.source_type == "upload" and @poster_link.media.source_path do %>
                    <img
                      src={MykonosBiennale.Uploads.media_url(@poster_link.media, size: "thumb")}
                      alt={@poster_link.media.caption || field(@event, "title")}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <.icon name="hero-photo" class="w-8 h-8 text-gray-400" />
                  <% end %>
                </div>
                <div class="p-2 text-xs text-gray-600 truncate">
                  {@poster_link.media.caption || "Untitled"}
                </div>
              </div>
              <button
                type="button"
                phx-click="remove_poster"
                phx-target={@myself}
                class="absolute -top-2 -right-2 bg-red-600 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          <% else %>
            <div class="space-y-3">
              <div
                class="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center hover:border-blue-500 transition-colors"
                phx-drop-target={@uploads.poster.ref}
              >
                <.live_file_input upload={@uploads.poster} class="hidden" />
                <button
                  type="button"
                  phx-click={JS.dispatch("click", to: "##{@uploads.poster.ref}")}
                  class="text-blue-600 hover:text-blue-700 font-medium text-sm"
                >
                  Click to upload poster
                </button>
                <p class="mt-1 text-xs text-gray-500">
                  JPG, PNG, WEBP up to 10MB
                </p>
              </div>

              <%= for entry <- @uploads.poster.entries do %>
                <div class="flex items-center justify-between bg-gray-50 p-2 rounded">
                  <div class="flex items-center gap-2">
                    <%= if entry.done? do %>
                      <.icon name="hero-check-circle" class="w-4 h-4 text-green-500" />
                    <% else %>
                      <div class="w-4 h-4 rounded-full border-2 border-purple-500 border-t-transparent animate-spin"></div>
                    <% end %>
                    <span class="text-sm text-gray-900">{entry.client_name}</span>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel-poster-upload"
                    phx-value-ref={entry.ref}
                    phx-target={@myself}
                    class="text-red-600 hover:text-red-700"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% end %>

              <%= if @uploads.poster.entries != [] and Enum.all?(@uploads.poster.entries, & &1.done?) do %>
                <button
                  type="button"
                  phx-click="save_poster_upload"
                  phx-target={@myself}
                  class="px-4 py-2 bg-purple-600 text-white rounded-lg text-sm font-medium hover:bg-purple-700"
                >
                  Save Poster
                </button>
              <% end %>

              <%= for err <- upload_errors(@uploads.poster) do %>
                <p class="text-sm text-red-600">{error_to_string(err)}</p>
              <% end %>

              <div class="pt-2 border-t">
                <form phx-change="attach_poster" phx-target={@myself}>
                  <select
                    name="media_id"
                    class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
                  >
                    <option value="">Or select existing media...</option>
                    <%= for media <- @available_media do %>
                      <option value={media.id}>
                        {media.caption || "#{media.source_type} - #{media.id}"}
                      </option>
                    <% end %>
                  </select>
                </form>
              </div>
            </div>
          <% end %>
        </div>

        <div class="mt-6 border-t pt-6">
          <label class="block text-sm font-semibold text-gray-900 mb-2">
            Art Board — Selected ({length(@artboard_selected_media)})
          </label>
          <p class="text-xs text-gray-500 mb-3">
            Drag to reorder. Click an image to remove it from the selection.
          </p>

          <%= if @artboard_selected_media == [] do %>
            <p class="text-sm text-gray-500 mb-4">
              No media selected yet. Pick from the pool below.
            </p>
          <% else %>
            <div
              id="artboard-selected"
              phx-hook="SortableMediaLinks"
              phx-target={@myself}
              data-sortable-event="reorder_artboard"
              class="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-2 mb-4"
            >
              <div
                :for={media <- @artboard_selected_media}
                data-media-id={media.id}
                draggable="true"
                class="relative group bg-gray-50 rounded overflow-hidden cursor-pointer"
                phx-click="remove_from_artboard"
                phx-value-media-id={media.id}
                phx-target={@myself}
              >
                <div class="aspect-square bg-gray-100 flex items-center justify-center">
                  <%= if media.source_type == "upload" and media.source_path do %>
                    <img
                      src={MykonosBiennale.Uploads.media_url(media, size: "thumb")}
                      alt={media.caption}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <.icon name="hero-photo" class="w-4 h-4 text-gray-400" />
                  <% end %>
                </div>
                <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                  <.icon name="hero-x-mark" class="w-4 h-4 text-white" />
                </div>
              </div>
            </div>
          <% end %>

          <div class="border-t pt-4">
            <label class="block text-sm font-semibold text-gray-900 mb-2">
              Art Board — Available Pool ({length(@artboard_pool)})
            </label>
            <p class="text-xs text-gray-500 mb-3">
              <%= if @is_exhibition do %>
                Media from artworks linked to this event. Click to add to selection.
              <% else %>
                Media attached to this event. Click to add to selection.
              <% end %>
            </p>

            <%= if @artboard_pool == [] do %>
              <p class="text-sm text-gray-500">
                <%= if @is_exhibition do %>
                  No artworks linked to this event yet. Link artworks first.
                <% else %>
                  No media attached to this event yet. Use the upload/attach below.
                <% end %>
              </p>
            <% else %>
              <div class="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-2 max-h-80 overflow-y-auto">
                <div
                  :for={item <- @artboard_pool}
                  class="relative group bg-gray-50 rounded overflow-hidden cursor-pointer border-2 border-transparent hover:border-blue-500 transition-colors"
                  phx-click="add_to_artboard"
                  phx-value-media-id={item.media.id}
                  phx-target={@myself}
                >
                  <div class="aspect-square bg-gray-100 flex items-center justify-center">
                    <%= if item.media.source_type == "upload" and item.media.source_path do %>
                      <img
                        src={MykonosBiennale.Uploads.media_url(item.media, size: "thumb")}
                        alt={item.media.caption}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <.icon name="hero-photo" class="w-4 h-4 text-gray-400" />
                    <% end %>
                  </div>
                  <div class="absolute inset-0 bg-blue-500/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <.icon name="hero-plus" class="w-4 h-4 text-white" />
                  </div>
                </div>
              </div>
            <% end %>

            <%= if not @is_exhibition do %>
              <div class="mt-4 pt-4 border-t space-y-3">
                <label class="block text-sm font-medium text-gray-700">
                  Upload / Attach Media to Event
                </label>

                <form phx-change="attach_media" phx-target={@myself}>
                  <select
                    name="media_id"
                    class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
                  >
                    <option value="">Select media to attach...</option>
                    <%= for media <- @available_media do %>
                      <option value={media.id}>
                        {media.caption || "#{media.source_type} - #{media.id}"}
                      </option>
                    <% end %>
                  </select>
                </form>

                <div
                  class="border-2 border-dashed border-gray-300 rounded-lg p-3 text-center hover:border-blue-500 transition-colors"
                  phx-drop-target={@uploads.images.ref}
                >
                  <.live_file_input upload={@uploads.images} class="hidden" />
                  <button
                    type="button"
                    phx-click={JS.dispatch("click", to: "##{@uploads.images.ref}")}
                    class="text-blue-600 hover:text-blue-700 font-medium text-sm"
                  >
                    Click to upload images
                  </button>
                </div>

                <%= for entry <- @uploads.images.entries do %>
                  <div class="flex items-center gap-3">
                    <%= if entry.done? do %>
                      <.icon name="hero-check-circle" class="w-4 h-4 text-green-500" />
                    <% else %>
                      <div class="w-4 h-4 rounded-full border-2 border-purple-500 border-t-transparent animate-spin"></div>
                    <% end %>
                    <span class="text-xs text-gray-600 flex-1 truncate">{entry.client_name}</span>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      phx-target={@myself}
                      class="text-red-500 hover:text-red-700"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                <% end %>

                <%= if @uploads.images.entries != [] and Enum.all?(@uploads.images.entries, & &1.done?) do %>
                  <button
                    type="button"
                    phx-click="save_uploads"
                    phx-target={@myself}
                    class="px-4 py-2 bg-purple-600 text-white rounded-lg text-sm font-medium hover:bg-purple-700"
                  >
                    Save {length(@uploads.images.entries)} image(s)
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(%{event: event} = assigns, socket) do
    current_media_links =
      if event.id do
        Content.list_entity_media_links_for_entity(event)
      else
        []
      end

    all_media = Content.list_media()
    attached_ids = Enum.map(current_media_links, & &1.media_id)
    available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

    event_type = event.fields["type"] || "event"
    is_screening = event_type == "screening"
    is_exhibition = event_type == "exhibition"

    poster_link = if event.id != nil, do: Content.get_event_poster_link(event), else: nil

    {artboard_pool, artboard_artwork_map} =
      if event.id != nil and not is_screening do
        compute_artboard_pool(event, is_exhibition, current_media_links, poster_link)
      else
        {[], %{}}
      end

    artboard_selected_ids =
      event.fields
      |> Map.get("artboard_media_ids", [])
      |> Enum.map(fn id -> if is_binary(id), do: String.to_integer(id), else: id end)

    artboard_selected_media =
      artboard_selected_ids
      |> Enum.map(fn id ->
        Enum.find_value(artboard_pool, fn %{media: m} -> if m.id == id, do: m end)
      end)
      |> Enum.reject(&is_nil/1)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:biennales, Content.list_biennales())
     |> assign(:projects, Content.list_projects())
     |> assign(:current_media_links, current_media_links)
     |> assign(:available_media, available_media)
     |> assign(:is_screening, is_screening)
     |> assign(:is_exhibition, is_exhibition)
     |> assign(:poster_link, poster_link)
     |> assign(:artboard_pool, artboard_pool)
     |> assign(:artboard_artwork_map, artboard_artwork_map)
     |> assign(:artboard_selected_ids, artboard_selected_ids)
     |> assign(:artboard_selected_media, artboard_selected_media)
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 20,
       max_file_size: 20_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> allow_upload(:poster,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_new(:form, fn ->
       changeset = EventForm.changeset(%EventForm{}, event_form_attrs(event))
       to_form(changeset, as: :event)
     end)}
  end

  defp compute_artboard_pool(event, true = _is_exhibition, _current_media_links, _poster_link) do
    artwork_media = Content.list_event_artwork_media(event)

    pool =
      artwork_media
      |> Enum.map(fn %{media: media, artwork: artwork} -> %{media: media, artwork: artwork} end)

    artwork_map =
      Enum.into(artwork_media, %{}, fn %{media: media, artwork: artwork} ->
        {media.id, artwork}
      end)

    {pool, artwork_map}
  end

  defp compute_artboard_pool(_event, false = _is_exhibition, current_media_links, poster_link) do
    poster_media_id = if poster_link, do: poster_link.media_id, else: nil

    pool =
      current_media_links
      |> Enum.reject(fn link -> link.media_id == poster_media_id end)
      |> Enum.map(fn link -> %{media: link.media, artwork: nil} end)

    {pool, %{}}
  end

  defp reload_artboard(socket) do
    event = socket.assigns.event
    current_media_links = Content.list_entity_media_links_for_entity(event)
    poster_link = Content.get_event_poster_link(event)

    {artboard_pool, artboard_artwork_map} =
      compute_artboard_pool(event, socket.assigns.is_exhibition, current_media_links, poster_link)

    artboard_selected_ids =
      event.fields
      |> Map.get("artboard_media_ids", [])
      |> Enum.map(fn id -> if is_binary(id), do: String.to_integer(id), else: id end)

    artboard_selected_media =
      artboard_selected_ids
      |> Enum.map(fn id ->
        Enum.find_value(artboard_pool, fn %{media: m} -> if m.id == id, do: m end)
      end)
      |> Enum.reject(&is_nil/1)

    all_media = Content.list_media()
    attached_ids = Enum.map(current_media_links, & &1.media_id)
    available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

    socket
    |> assign(:current_media_links, current_media_links)
    |> assign(:available_media, available_media)
    |> assign(:poster_link, poster_link)
    |> assign(:artboard_pool, artboard_pool)
    |> assign(:artboard_artwork_map, artboard_artwork_map)
    |> assign(:artboard_selected_ids, artboard_selected_ids)
    |> assign(:artboard_selected_media, artboard_selected_media)
  end

  @impl true
  def handle_event("validate", params, socket) do
    event_params = extract_event_params(params)

    changeset =
      socket.assigns.form.source.data
      |> EventForm.changeset(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :event))}
  end

  def handle_event("attach_media", %{"media_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_media", %{"media_id" => media_id}, socket) do
    event = socket.assigns.event

    if event.id do
      media = Content.get_media!(media_id)

      case Content.attach_media_to_entity(event, media) do
        {:ok, :attached} ->
          {:noreply,
           socket
           |> reload_artboard()
           |> put_flash(:info, "Media attached successfully")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the event first before attaching media")}
    end
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    event = socket.assigns.event
    media = Content.get_media!(media_id)

    {:ok, :detached} = Content.detach_media_from_entity(event, media)

    {:noreply,
     socket
     |> reload_artboard()
     |> put_flash(:info, "Media detached successfully")}
  end

  def handle_event("reorder_media_links", %{"media_ids" => media_ids}, socket) do
    event = socket.assigns.event
    media_ids = Enum.map(media_ids, &String.to_integer/1)
    {:ok, :reordered} = Content.reorder_entity_media(event, media_ids)

    current_media_links = Content.list_entity_media_links_for_entity(event)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("update_media_link", %{"media_id" => media_id, "metadata" => metadata}, socket) do
    event = socket.assigns.event
    media = %Media{id: String.to_integer(media_id)}
    {:ok, :updated} = Content.update_entity_media_link(event, media, metadata)

    current_media_links = Content.list_entity_media_links_for_entity(event)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("save", params, socket) do
    event_params = extract_event_params(params)
    save_event(socket, socket.assigns.action, event_params)
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  def handle_event("save_uploads", _params, socket) do
    event = socket.assigns.event
    title = event.fields["title"] || "Untitled"

    biennale_year =
      case event_biennale_year(event) do
        nil -> ""
        year -> " #{year}"
      end

    caption = String.trim("#{title}#{biennale_year}")

    results =
      consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = MykonosBiennale.Uploads.uploads_path(filename)

        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.cp!(path, dest)

        case Content.create_media(%{
               source_type: "upload",
               source_path: filename,
               mime_type: entry.client_type,
               original_name: entry.client_name,
               caption: caption
             }) do
          {:ok, media} ->
            Content.attach_media_to_entity(event, media)
            {:ok, media}

          {:error, _} = err ->
            err
        end
      end)

    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)

    socket =
      socket
      |> reload_artboard()

    flash =
      cond do
        error_count > 0 and success_count > 0 ->
          "Uploaded #{success_count} image(s), #{error_count} failed"

        error_count > 0 ->
          "Upload failed for #{error_count} image(s)"

        true ->
          "Uploaded #{success_count} image(s) successfully"
      end

    flash_type = if error_count > 0 and success_count == 0, do: :error, else: :info

    {:noreply, put_flash(socket, flash_type, flash)}
  end

  def handle_event("cancel-poster-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :poster, ref)}
  end

  def handle_event("save_poster_upload", _params, socket) do
    event = socket.assigns.event
    title = event.fields["title"] || "Untitled"

    results =
      consume_uploaded_entries(socket, :poster, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = MykonosBiennale.Uploads.uploads_path(filename)

        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.cp!(path, dest)

        case Content.create_media(%{
               source_type: "upload",
               source_path: filename,
               mime_type: entry.client_type,
               original_name: entry.client_name,
               caption: title
             }) do
          {:ok, media} ->
            set_poster(event, media)
            {:ok, media}

          {:error, _} = err ->
            err
        end
      end)

    socket =
      case results do
        [{:ok, _} | _] ->
          socket
          |> reload_artboard()
          |> put_flash(:info, "Poster saved")

        _ ->
          put_flash(socket, :error, "Could not save poster")
      end

    {:noreply, socket}
  end

  def handle_event("attach_poster", %{"media_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_poster", %{"media_id" => media_id}, socket) do
    event = socket.assigns.event
    media = Content.get_media!(media_id)

    case set_poster(event, media) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_artboard()
         |> put_flash(:info, "Poster set")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not set poster: #{inspect(reason)}")}
    end
  end

  def handle_event("remove_poster", _params, socket) do
    event = socket.assigns.event
    poster_link = socket.assigns.poster_link

    if poster_link do
      media = %Media{id: poster_link.media_id}
      {:ok, :detached} = Content.detach_media_from_entity(event, media)
    end

    {:noreply,
     socket
     |> reload_artboard()
     |> put_flash(:info, "Poster removed")}
  end

  def handle_event("add_to_artboard", %{"media-id" => media_id}, socket) do
    event = socket.assigns.event
    media_id = String.to_integer(media_id)

    current_ids = socket.assigns.artboard_selected_ids
    new_ids = if media_id in current_ids, do: current_ids, else: current_ids ++ [media_id]

    case Content.update_event(event, %{artboard_media_ids: new_ids}) do
      {:ok, updated_event} ->
        socket =
          socket
          |> assign(:event, updated_event)
          |> reload_artboard()

        {:noreply, put_flash(socket, :info, "Added to art board")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update art board")}
    end
  end

  def handle_event("remove_from_artboard", %{"media-id" => media_id}, socket) do
    event = socket.assigns.event
    media_id = String.to_integer(media_id)

    new_ids = List.delete(socket.assigns.artboard_selected_ids, media_id)

    case Content.update_event(event, %{artboard_media_ids: new_ids}) do
      {:ok, updated_event} ->
        socket =
          socket
          |> assign(:event, updated_event)
          |> reload_artboard()

        {:noreply, put_flash(socket, :info, "Removed from art board")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update art board")}
    end
  end

  def handle_event("reorder_artboard", %{"media_ids" => media_ids}, socket) do
    event = socket.assigns.event
    new_ids = Enum.map(media_ids, &String.to_integer/1)

    case Content.update_event(event, %{artboard_media_ids: new_ids}) do
      {:ok, updated_event} ->
        socket =
          socket
          |> assign(:event, updated_event)
          |> reload_artboard()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reorder art board")}
    end
  end

  defp set_poster(event, media) do
    existing_poster = Content.get_event_poster_link(event)

    if existing_poster do
      old_media = %Media{id: existing_poster.media_id}
      {:ok, :detached} = Content.detach_media_from_entity(event, old_media)
    end

    Content.attach_media_to_entity(event, media, metadata: %{"role" => "poster"})
  end

  defp handle_progress(:images, _entry, socket) do
    {:noreply, socket}
  end

  defp event_biennale_year(%Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, fn
           %Relationship{relationship_type: %Content.RelationshipType{slug: "biennale_event"}} ->
             true

           _ ->
             false
         end) do
      %Relationship{object_id: biennale_id} when is_integer(biennale_id) ->
        case Content.get_entity!(biennale_id) do
          %Entity{fields: %{"year" => year}} -> year
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp event_biennale_year(_), do: nil

  defp save_event(socket, :edit, event_params) do
    changeset = EventForm.changeset(socket.assigns.form.source.data, event_params)

    if changeset.valid? do
      attrs = event_attrs_from_form(changeset)

      case Content.update_event(socket.assigns.event, attrs) do
        {:ok, event} ->
          notify_parent({:saved, event})

          {:noreply,
           socket
           |> put_flash(:info, "Event updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = entity_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update event")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :event)
           )
           |> assign(:entity_changeset, entity_changeset)}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :event))}
    end
  end

  defp save_event(socket, :new, event_params) do
    changeset = EventForm.changeset(socket.assigns.form.source.data, event_params)

    if changeset.valid? do
      attrs = event_attrs_from_form(changeset)

      case Content.create_event(attrs) do
        {:ok, event} ->
          notify_parent({:saved, event})

          {:noreply,
           socket
           |> put_flash(:info, "Event created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = entity_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create event")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :event)
           )
           |> assign(:entity_changeset, entity_changeset)}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :event))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp extract_event_params(%{"event" => p}) when is_map(p) do
    p
    |> Enum.map(fn
      {key, ""} when key in ["project_id", "biennale_id"] -> {key, nil}
      other -> other
    end)
    |> Enum.into(%{})
  end

  defp extract_event_params(%{"entity" => p}) when is_map(p), do: p
  defp extract_event_params(_), do: %{}

  defp event_form_attrs(%Content.Entity{fields: fields, as_subject: rels})
       when is_map(fields) and is_list(rels) do
    %{
      project_id: relationship_id_by_slug(rels, "event_project"),
      title: Map.get(fields, "title"),
      type: Map.get(fields, "type"),
      biennale_id: relationship_id_by_slug(rels, "biennale_event"),
      date: map_get_date(fields, "date"),
      time: Map.get(fields, "time"),
      location: Map.get(fields, "location"),
      tickets: Map.get(fields, "tickets"),
      description: Map.get(fields, "description"),
      show_project: Map.get(fields, "show_project", true),
      visible: true
    }
  end

  defp event_form_attrs(%Content.Entity{fields: fields}) when is_map(fields) do
    %{
      title: Map.get(fields, "title"),
      type: Map.get(fields, "type"),
      date: map_get_date(fields, "date"),
      time: Map.get(fields, "time"),
      location: Map.get(fields, "location"),
      tickets: Map.get(fields, "tickets"),
      description: Map.get(fields, "description"),
      show_project: Map.get(fields, "show_project", true),
      visible: true
    }
  end

  defp event_form_attrs(%Content.Entity{}), do: %{visible: true, show_project: true}

  defp relationship_id_by_slug(rels, slug) when is_list(rels) do
    case Enum.find(rels, fn
           %Relationship{relationship_type: %Content.RelationshipType{slug: ^slug}} -> true
           _ -> false
         end) do
      %Relationship{object_id: id} when is_integer(id) -> id
      _ -> nil
    end
  end

  defp map_get_date(map, key) do
    case Map.get(map, key) do
      %Date{} = d ->
        d

      s when is_binary(s) ->
        case Date.from_iso8601(s) do
          {:ok, d} -> d
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp event_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    %{
      project_id: form.project_id,
      title: form.title,
      type: form.type,
      biennale_id: form.biennale_id,
      date: form.date,
      time: form.time,
      location: form.location,
      tickets: form.tickets,
      description: form.description,
      show_project: form.show_project,
      visible: form.visible
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp field(entity, key, default \\ nil)

  defp field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(_, _key, default), do: default

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
