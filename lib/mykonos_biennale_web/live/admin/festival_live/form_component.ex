defmodule MykonosBiennaleWeb.Admin.FestivalLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias Ecto.Changeset

  defmodule FestivalForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :year, :integer
      field :title, :string
      field :statement, :string
      field :template, :string
      field :css, :string
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [:year, :title, :statement, :template, :css, :visible])
      |> validate_required([:year, :title])
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
        id="festival-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:year]} type="number" label="Year" required />
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:statement]} type="textarea" label="Statement" rows="3" />
          <.input field={@form[:template]} type="textarea" label="Template" rows="5" />
          <.input field={@form[:css]} type="textarea" label="CSS" rows="5" />
        </div>

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
              id="festival-media-links"
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

                  <%!-- Editable per-link metadata stored in entity_media.metadata --%>
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
            <%!-- Keep this separate from the main form's phx-change="validate" so the change event
                 doesn't get swallowed by the parent form validation. --%>
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

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-400 hover:text-white">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Festival
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{festival: festival} = assigns, socket) do
    current_media_links =
      if festival.id do
        Content.list_entity_media_links_for_entity(festival)
      else
        []
      end

    all_media = Content.list_media()
    attached_ids = Enum.map(current_media_links, & &1.media_id)
    available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_media_links, current_media_links)
     |> assign(:available_media, available_media)
     |> assign_new(:form, fn ->
       changeset = FestivalForm.changeset(%FestivalForm{}, festival_form_attrs(festival))
       to_form(changeset, as: :festival)
     end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    festival_params = extract_festival_params(params)

    changeset =
      socket.assigns.form.source.data
      |> FestivalForm.changeset(festival_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :festival))}
  end

  def handle_event("attach_media", %{"media_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_media", %{"media_id" => media_id}, socket) do
    festival = socket.assigns.festival

    if festival.id do
      media = Content.get_media!(media_id)

      case Content.attach_media_to_entity(festival, media) do
        {:ok, _} ->
          current_media_links = Content.list_entity_media_links_for_entity(festival)
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
      {:noreply, put_flash(socket, :error, "Save the festival first before attaching media")}
    end
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    festival = socket.assigns.festival
    media = Content.get_media!(media_id)

    {:ok, :detached} = Content.detach_media_from_entity(festival, media)

    current_media_links = Content.list_entity_media_links_for_entity(festival)
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
    festival = socket.assigns.festival
    media_ids = Enum.map(media_ids, &String.to_integer/1)
    {:ok, :reordered} = Content.reorder_entity_media(festival, media_ids)

    current_media_links = Content.list_entity_media_links_for_entity(festival)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("update_media_link", %{"media_id" => media_id, "metadata" => metadata}, socket) do
    festival = socket.assigns.festival
    media = %Media{id: String.to_integer(media_id)}
    {:ok, :updated} = Content.update_entity_media_link(festival, media, metadata)

    current_media_links = Content.list_entity_media_links_for_entity(festival)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("save", params, socket) do
    festival_params = extract_festival_params(params)
    save_festival(socket, socket.assigns.action, festival_params)
  end

  defp save_festival(socket, :edit, festival_params) do
    changeset = FestivalForm.changeset(socket.assigns.form.source.data, festival_params)

    if changeset.valid? do
      attrs = festival_attrs_from_form(changeset)

      case Content.update_festival(socket.assigns.festival, attrs) do
        {:ok, festival} ->
          notify_parent({:saved, festival})

          {:noreply,
           socket
           |> put_flash(:info, "Festival updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = entity_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update festival")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :festival)
           )
           |> assign(:entity_changeset, entity_changeset)}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :festival))}
    end
  end

  defp save_festival(socket, :new, festival_params) do
    changeset = FestivalForm.changeset(socket.assigns.form.source.data, festival_params)

    if changeset.valid? do
      attrs = festival_attrs_from_form(changeset)

      case Content.create_festival(attrs) do
        {:ok, festival} ->
          notify_parent({:saved, festival})

          {:noreply,
           socket
           |> put_flash(:info, "Festival created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = entity_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create festival")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :festival)
           )
           |> assign(:entity_changeset, entity_changeset)}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :festival))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp extract_festival_params(%{"festival" => p}) when is_map(p), do: p
  defp extract_festival_params(%{"entity" => p}) when is_map(p), do: p
  defp extract_festival_params(_), do: %{}

  defp festival_form_attrs(%Content.Entity{fields: fields}) when is_map(fields) do
    %{
      year: map_get_int(fields, "year"),
      title: Map.get(fields, "title"),
      statement: Map.get(fields, "statement"),
      template: Map.get(fields, "template"),
      css: Map.get(fields, "css"),
      visible: true
    }
  end

  defp festival_form_attrs(%Content.Entity{}), do: %{visible: true}

  defp map_get_int(map, key) do
    case Map.get(map, key) do
      i when is_integer(i) ->
        i

      s when is_binary(s) ->
        case Integer.parse(s) do
          {i, _} -> i
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp festival_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    %{
      year: form.year,
      title: form.title,
      statement: form.statement,
      template: form.template,
      css: form.css
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
