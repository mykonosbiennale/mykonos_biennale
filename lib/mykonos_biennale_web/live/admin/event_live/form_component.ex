defmodule MykonosBiennaleWeb.Admin.EventLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Content.Media
  alias Ecto.Changeset

  defmodule EventForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :festival_id, :integer
      field :project_id, :integer
      field :title, :string
      field :type, :string
      field :biennale_id, :integer
      field :date, :date
      field :time, :string
      field :location, :string
      field :tickets, :string
      field :description, :string
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [
        :festival_id,
        :project_id,
        :title,
        :type,
        :biennale_id,
        :date,
        :time,
        :location,
        :tickets,
        :description,
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
      </.header>

      <.form
        for={@form}
        id="event-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
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
              {"Video Graffiti", "video_graffiti"},
              {"Dramatic Nights", "dramatic_nights"},
              {"Short Films", "short_films"},
              {"Workshop", "workshop"}
            ]}
            required
          />

          <.input
            field={@form[:festival_id]}
            type="select"
            label="Festival"
            prompt="Choose a festival"
            options={Enum.map(@festivals, &{&1.fields["title"] || &1.fields["year"], &1.id})}
          />

          <.input field={@form[:date]} type="date" label="Date" />
          <.input field={@form[:time]} type="time" label="Time" />
          <.input field={@form[:location]} type="text" label="Location" />
          <.input field={@form[:tickets]} type="text" label="Tickets URL" />
          <.input field={@form[:description]} type="textarea" label="Description" rows="5" />
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
                        src={"/uploads/#{link.media.source_path}"}
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
      </div>
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

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:biennales, Content.list_biennales())
     |> assign(:festivals, Content.list_festivals())
     |> assign(:projects, Content.list_projects())
     |> assign(:current_media_links, current_media_links)
     |> assign(:available_media, available_media)
     |> assign_new(:form, fn ->
       changeset = EventForm.changeset(%EventForm{}, event_form_attrs(event))
       to_form(changeset, as: :event)
     end)}
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
          current_media_links = Content.list_entity_media_links_for_entity(event)
          all_media = Content.list_media()
          attached_ids = Enum.map(current_media_links, & &1.media_id)
          available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

          {:noreply,
           socket
           |> assign(:current_media_links, current_media_links)
           |> assign(:available_media, available_media)
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

    current_media_links = Content.list_entity_media_links_for_entity(event)
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
      {key, ""} when key in ["festival_id", "project_id", "biennale_id"] -> {key, nil}
      other -> other
    end)
    |> Enum.into(%{})
  end

  defp extract_event_params(%{"entity" => p}) when is_map(p), do: p
  defp extract_event_params(_), do: %{}

  defp event_form_attrs(%Content.Entity{fields: fields, as_subject: rels})
       when is_map(fields) and is_list(rels) do
    %{
      festival_id: relationship_id_by_slug(rels, "event_festival"),
      project_id: relationship_id_by_slug(rels, "event_project"),
      title: Map.get(fields, "title"),
      type: Map.get(fields, "type"),
      biennale_id: relationship_id_by_slug(rels, "biennale_event"),
      date: map_get_date(fields, "date"),
      time: Map.get(fields, "time"),
      location: Map.get(fields, "location"),
      tickets: Map.get(fields, "tickets"),
      description: Map.get(fields, "description"),
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
      visible: true
    }
  end

  defp event_form_attrs(%Content.Entity{}), do: %{visible: true}

  defp relationship_id_by_slug(rels, slug) when is_list(rels) do
    case Enum.find(rels, &match?(%Relationship{slug: ^slug}, &1)) do
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
      festival_id: form.festival_id,
      project_id: form.project_id,
      title: form.title,
      type: form.type,
      biennale_id: form.biennale_id,
      date: form.date,
      time: form.time,
      location: form.location,
      tickets: form.tickets,
      description: form.description,
      visible: form.visible
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
