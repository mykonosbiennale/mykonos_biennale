defmodule MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias Ecto.Changeset

  @artwork_types [
    {"Video", "video"},
    {"Film", "film"},
    {"Performance", "performance"},
    {"Artwork", "artwork"}
  ]

  defmodule ArtworkForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :title, :string
      field :date, :string
      field :description, :string
      field :medium, :string
      field :size, :string
      field :type, :string
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [:title, :date, :description, :medium, :size, :type, :visible])
      |> validate_required([:title])
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
            :if={@artwork.id}
            href={"/art/#{@artwork.id}"}
            target="_blank"
            class="text-sm text-blue-600 hover:text-blue-700"
          >
            See on Site
          </.link>
        </:actions>
      </.header>

      <.form
        for={@form}
        id="artwork-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:date]} type="text" label="Date (Year)" placeholder="2025" />
            <.input
              field={@form[:type]}
              type="select"
              label="Type"
              options={@artwork_types}
              prompt="Select type"
            />
          </div>

          <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:medium]} type="text" label="Medium" placeholder="Oil on canvas" />
            <.input field={@form[:size]} type="text" label="Size" placeholder="100 x 80 cm" />
          </div>

          <div class="space-y-2">
            <label class="block text-sm font-semibold text-gray-900">
              Images
            </label>

            <%= if @current_media_links == [] do %>
              <p class="text-sm text-gray-500 mb-4">
                No images uploaded yet
              </p>
            <% else %>
              <p class="text-xs text-gray-500 mb-2">
                Drag to reorder. Changes are saved immediately.
              </p>

              <div
                id="artwork-media-links"
                phx-hook="SortableMediaLinks"
                phx-target={@myself}
                class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-4"
              >
                <div
                  :for={link <- @current_media_links}
                  data-media-id={link.media_id}
                  draggable="true"
                  class="relative group bg-gray-50 rounded-lg overflow-hidden"
                >
                  <div class="aspect-video bg-gray-100 flex items-center justify-center">
                    <%= if link.media.source_path do %>
                      <img
                        src={MykonosBiennale.Uploads.media_url(link.media, size: "thumb")}
                        alt={link.media.alt_text || link.media.caption}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <.icon name="hero-photo" class="w-8 h-8 text-gray-400" />
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
                  <div class="p-2">
                    <div class="text-xs text-gray-600 truncate">
                      {link.media.caption || "Untitled"}
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <div
              class="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center hover:border-blue-500 transition-colors"
              phx-drop-target={@uploads.artwork_image.ref}
            >
              <.live_file_input upload={@uploads.artwork_image} class="hidden" />
              <button
                type="button"
                phx-click={JS.dispatch("click", to: "##{@uploads.artwork_image.ref}")}
                class="text-blue-600 hover:text-blue-700 font-medium text-sm"
              >
                Click to upload or drag and drop
              </button>
              <p class="mt-1 text-xs text-gray-500">
                JPG, PNG, WEBP up to 10MB
              </p>
            </div>

            <%= for entry <- @uploads.artwork_image.entries do %>
              <div class="flex items-center justify-between bg-gray-50 p-2 rounded">
                <div class="flex items-center gap-2">
                  <.icon name="hero-document" class="w-4 h-4 text-gray-400" />
                  <span class="text-sm text-gray-900">{entry.client_name}</span>
                  <span class="text-xs text-gray-500">{format_bytes(entry.client_size)}</span>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  phx-target={@myself}
                  class="text-red-600 hover:text-red-700"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
            <% end %>

            <%= for err <- upload_errors(@uploads.artwork_image) do %>
              <p class="text-sm text-red-600">{error_to_string(err)}</p>
            <% end %>
          </div>
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Artwork
          </button>
        </div>
      </.form>

      <div class="mt-6">
        <label class="block text-sm font-semibold text-gray-900 mb-2">
          Events
        </label>

        <%= if @linked_events == [] do %>
          <p class="text-sm text-gray-500 mb-4">
            No events linked yet
          </p>
        <% else %>
          <div class="space-y-2 mb-4">
            <div
              :for={rel <- @linked_events}
              class="flex items-center justify-between bg-gray-50 p-3 rounded-lg"
            >
              <div>
                <div class="text-sm font-medium text-gray-900">
                  {field(rel.object, "title")}
                </div>
                <div class="text-xs text-gray-500">
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                    {rel.relationship_type.label}
                  </span>
                  <%= if field(rel.object, "type") do %>
                    <span class="ml-1">{field(rel.object, "type")}</span>
                  <% end %>
                </div>
              </div>
              <button
                type="button"
                phx-click="detach_event"
                phx-value-event-id={rel.object_id}
                phx-target={@myself}
                class="text-red-600 hover:text-red-700"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          </div>
        <% end %>

        <%= if @artwork.id do %>
          <form phx-change="attach_event" phx-target={@myself}>
            <select
              name="event_id"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">Select an event to link...</option>
              <%= for event <- @available_events do %>
                <option value={event.id}>
                  {field(event, "title")} ({field(event, "type") || "untyped"})
                </option>
              <% end %>
            </select>
          </form>
        <% else %>
          <p class="text-xs text-gray-500">Save the artwork first to link events.</p>
        <% end %>
      </div>

      <div class="mt-6">
        <label class="block text-sm font-semibold text-gray-900 mb-2">
          Participants
        </label>

        <%= if @linked_participants == [] do %>
          <p class="text-sm text-gray-500 mb-4">
            No participants linked yet
          </p>
        <% else %>
          <div class="space-y-2 mb-4">
            <div
              :for={rel <- @linked_participants}
              class="flex items-center justify-between bg-gray-50 p-3 rounded-lg"
            >
              <div>
                <div class="text-sm font-medium text-gray-900">
                  {field(rel.object, "first_name")} {field(rel.object, "last_name")}
                </div>
                <div class="text-xs text-gray-500">
                  <%= if rel.fields["label"] do %>
                    <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      {rel.fields["label"]}
                    </span>
                  <% end %>
                  <%= if rel.fields["role"] do %>
                    <span class="ml-1 inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      {rel.fields["role"]}
                    </span>
                  <% end %>
                </div>
              </div>
              <button
                type="button"
                phx-click="detach_participant"
                phx-value-participant-id={rel.object_id}
                phx-target={@myself}
                class="text-red-600 hover:text-red-700"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          </div>
        <% end %>

        <%= if @artwork.id do %>
          <form phx-submit="attach_participant" phx-target={@myself}>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <select
                name="participant_id"
                class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
              >
                <option value="">Select a participant...</option>
                <%= for participant <- @available_participants do %>
                  <option value={participant.id}>
                    {field(participant, "first_name")} {field(participant, "last_name")}
                  </option>
                <% end %>
              </select>

              <div class="flex gap-2">
                <input
                  type="text"
                  name="role"
                  list="participant-roles"
                  placeholder="Role (e.g. creator, curator)"
                  class="flex-1 rounded-lg border-gray-300 bg-white text-gray-900 px-3 py-2"
                />
                <datalist id="participant-roles">
                  <option value="creator" />
                  <option value="curator" />
                  <option value="director" />
                  <option value="actor" />
                </datalist>
                <button
                  type="submit"
                  class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700"
                >
                  Add
                </button>
              </div>
            </div>
          </form>
        <% else %>
          <p class="text-xs text-gray-500">Save the artwork first to link participants.</p>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{artwork: artwork} = assigns, socket) do
    current_media_links =
      if artwork.id do
        Content.list_entity_media_links_for_entity(artwork)
      else
        []
      end

    all_media = Content.list_media()
    attached_ids = Enum.map(current_media_links, & &1.media_id)
    available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

    linked_events =
      if artwork.id do
        Content.list_artwork_linked_events(artwork)
      else
        []
      end

    all_events = Content.list_events()
    linked_event_ids = Enum.map(linked_events, & &1.object_id)
    available_events = Enum.reject(all_events, fn e -> e.id in linked_event_ids end)

    linked_participants =
      if artwork.id do
        Content.list_artwork_linked_participants(artwork)
      else
        []
      end

    all_participants = Content.list_participants()
    linked_participant_ids = Enum.map(linked_participants, & &1.object_id)

    available_participants =
      Enum.reject(all_participants, fn p -> p.id in linked_participant_ids end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:artwork_types, @artwork_types)
     |> assign(:current_media_links, current_media_links)
     |> assign(:available_media, available_media)
     |> assign(:linked_events, linked_events)
     |> assign(:available_events, available_events)
     |> assign(:linked_participants, linked_participants)
     |> assign(:available_participants, available_participants)
     |> assign_new(:form, fn ->
       changeset = ArtworkForm.changeset(%ArtworkForm{}, artwork_form_attrs(artwork))
       to_form(changeset, as: :artwork)
     end)
     |> allow_upload(:artwork_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 10,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_event("validate", params, socket) do
    artwork_params = extract_artwork_params(params)

    changeset =
      socket.assigns.form.source.data
      |> ArtworkForm.changeset(artwork_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :artwork))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :artwork_image, ref)}
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    artwork = socket.assigns.artwork
    media = Content.get_media!(media_id)

    {:ok, :detached} = Content.detach_media_from_entity(artwork, media)

    current_media_links = Content.list_entity_media_links_for_entity(artwork)
    all_media = Content.list_media()
    attached_ids = Enum.map(current_media_links, & &1.media_id)
    available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

    {:noreply,
     socket
     |> assign(:current_media_links, current_media_links)
     |> assign(:available_media, available_media)
     |> put_flash(:info, "Media detached successfully")}
  end

  def handle_event("reorder_media_links", %{"media_ids" => media_ids}, socket) do
    artwork = socket.assigns.artwork
    media_ids = Enum.map(media_ids, &String.to_integer/1)
    {:ok, :reordered} = Content.reorder_entity_media(artwork, media_ids)

    current_media_links = Content.list_entity_media_links_for_entity(artwork)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("attach_event", %{"event_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_event", %{"event_id" => event_id}, socket) do
    artwork = socket.assigns.artwork

    if artwork.id do
      event = Content.get_event!(event_id)

      case Content.attach_event_to_artwork(artwork, event) do
        {:ok, _} ->
          linked_events = Content.list_artwork_linked_events(artwork)
          all_events = Content.list_events()
          linked_event_ids = Enum.map(linked_events, & &1.object_id)
          available_events = Enum.reject(all_events, fn e -> e.id in linked_event_ids end)

          {:noreply,
           socket
           |> assign(:linked_events, linked_events)
           |> assign(:available_events, available_events)
           |> put_flash(:info, "Event linked successfully")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not link event: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the artwork first before linking events")}
    end
  end

  def handle_event("detach_event", %{"event-id" => event_id}, socket) do
    artwork = socket.assigns.artwork
    event_id = String.to_integer(event_id)

    {:ok, _} = Content.detach_event_from_artwork(artwork, event_id)

    linked_events = Content.list_artwork_linked_events(artwork)
    all_events = Content.list_events()
    linked_event_ids = Enum.map(linked_events, & &1.object_id)
    available_events = Enum.reject(all_events, fn e -> e.id in linked_event_ids end)

    {:noreply,
     socket
     |> assign(:linked_events, linked_events)
     |> assign(:available_events, available_events)
     |> put_flash(:info, "Event unlinked successfully")}
  end

  def handle_event("attach_participant", %{"participant_id" => "", "role" => _}, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "attach_participant",
        %{"participant_id" => participant_id, "role" => role},
        socket
      ) do
    artwork = socket.assigns.artwork

    if artwork.id do
      participant = Content.get_participant!(participant_id)

      case Content.attach_participant_to_artwork(artwork, participant, role) do
        {:ok, _} ->
          linked_participants = Content.list_artwork_linked_participants(artwork)
          all_participants = Content.list_participants()
          linked_participant_ids = Enum.map(linked_participants, & &1.object_id)

          available_participants =
            Enum.reject(all_participants, fn p -> p.id in linked_participant_ids end)

          {:noreply,
           socket
           |> assign(:linked_participants, linked_participants)
           |> assign(:available_participants, available_participants)
           |> put_flash(:info, "Participant linked successfully")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not link participant: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the artwork first before linking participants")}
    end
  end

  def handle_event("detach_participant", %{"participant-id" => participant_id}, socket) do
    artwork = socket.assigns.artwork
    participant_id = String.to_integer(participant_id)

    {:ok, _} = Content.detach_participant_from_artwork(artwork, participant_id)

    linked_participants = Content.list_artwork_linked_participants(artwork)
    all_participants = Content.list_participants()
    linked_participant_ids = Enum.map(linked_participants, & &1.object_id)

    available_participants =
      Enum.reject(all_participants, fn p -> p.id in linked_participant_ids end)

    {:noreply,
     socket
     |> assign(:linked_participants, linked_participants)
     |> assign(:available_participants, available_participants)
     |> put_flash(:info, "Participant unlinked successfully")}
  end

  def handle_event("save", params, socket) do
    artwork_params = extract_artwork_params(params)
    save_artwork(socket, socket.assigns.action, artwork_params)
  end

  defp save_artwork(socket, :edit, artwork_params) do
    changeset = ArtworkForm.changeset(socket.assigns.form.source.data, artwork_params)

    if changeset.valid? do
      attrs = artwork_attrs_from_form(changeset)

      case Content.update_artwork(socket.assigns.artwork, attrs) do
        {:ok, artwork} ->
          maybe_upload_images(socket, artwork)
          notify_parent({:saved, artwork})

          {:noreply,
           socket
           |> put_flash(:info, "Artwork updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update artwork")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :artwork)
           )}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :artwork))}
    end
  end

  defp save_artwork(socket, :new, artwork_params) do
    changeset = ArtworkForm.changeset(socket.assigns.form.source.data, artwork_params)

    if changeset.valid? do
      attrs = artwork_attrs_from_form(changeset)

      case Content.create_artwork(attrs) do
        {:ok, artwork} ->
          maybe_upload_images(socket, artwork)
          notify_parent({:saved, artwork})

          {:noreply,
           socket
           |> put_flash(:info, "Artwork created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create artwork")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :artwork)
           )}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :artwork))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp maybe_upload_images(socket, artwork) do
    uploaded_files =
      consume_uploaded_entries(socket, :artwork_image, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = MykonosBiennale.Uploads.uploads_path(filename)
        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.cp!(path, dest)
        {:ok, %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
      end)

    for %{path: path, mime_type: mime_type, original_name: original_name} <- uploaded_files do
      {:ok, media} =
        Content.create_media(%{
          caption: original_name,
          source_type: "upload",
          source_path: path,
          mime_type: mime_type,
          original_name: original_name
        })

      Content.attach_media_to_entity(artwork, media)
    end
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp extract_artwork_params(%{"artwork" => p}) when is_map(p), do: p
  defp extract_artwork_params(_), do: %{}

  defp artwork_form_attrs(%Content.Entity{fields: fields}) when is_map(fields) do
    %{
      title: Map.get(fields, "title"),
      date: Map.get(fields, "date"),
      description: Map.get(fields, "description"),
      medium: Map.get(fields, "medium"),
      size: Map.get(fields, "size"),
      type: Map.get(fields, "type"),
      visible: true
    }
  end

  defp artwork_form_attrs(%Content.Entity{}), do: %{visible: true}

  defp field(%Content.Entity{fields: fields}, key) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key))
  end

  defp field(_, _), do: nil

  defp artwork_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    %{
      title: form.title,
      date: form.date,
      description: form.description,
      medium: form.medium,
      size: form.size,
      type: form.type
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
