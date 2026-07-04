defmodule MykonosBiennaleWeb.Admin.BiennaleLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias MykonosBiennaleWeb.BiennaleHTML
  alias Ecto.Changeset

  defmodule BiennaleForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :year, :integer
      field :theme, :string
      field :statement, :string
      field :description, :string
      field :start_date, :date
      field :end_date, :date
      field :visible, :boolean, default: true
      field :template, :string, default: "default"
      field :show_program, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [
        :year,
        :theme,
        :statement,
        :description,
        :start_date,
        :end_date,
        :visible,
        :template,
        :show_program
      ])
      |> validate_required([:year, :theme])
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
        id="biennale-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:year]} type="number" label="Year" required />
          <.input field={@form[:theme]} type="text" label="Theme" required />
          <.input
            field={@form[:template]}
            type="select"
            label="Template"
            options={BiennaleHTML.template_options()}
          />
          <.input field={@form[:statement]} type="textarea" label="Statement" rows="3" />
          <.input field={@form[:description]} type="textarea" label="Description" rows="5" />
          <.input field={@form[:start_date]} type="date" label="Start Date" />
          <.input field={@form[:end_date]} type="date" label="End Date" />
          <.input field={@form[:show_program]} type="checkbox" label="Show program" />
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-400 hover:text-white">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Biennale
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
            id="biennale-media-links"
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
      </div>
    </div>
    """
  end

  @impl true
  def update(%{biennale: biennale} = assigns, socket) do
    current_media_links =
      if biennale.id do
        Content.list_entity_media_links_for_entity(biennale)
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
       changeset = BiennaleForm.changeset(%BiennaleForm{}, biennale_form_attrs(biennale))
       to_form(changeset, as: :biennale)
     end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    biennale_params = extract_biennale_params(params)

    changeset =
      socket.assigns.form.source.data
      |> BiennaleForm.changeset(biennale_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :biennale))}
  end

  def handle_event("attach_media", %{"media_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_media", %{"media_id" => media_id}, socket) do
    biennale = socket.assigns.biennale

    if biennale.id do
      media = Content.get_media!(media_id)

      case Content.attach_media_to_entity(biennale, media) do
        {:ok, :attached} ->
          current_media_links = Content.list_entity_media_links_for_entity(biennale)
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
      {:noreply, put_flash(socket, :error, "Save the biennale first before attaching media")}
    end
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    biennale = socket.assigns.biennale
    media = Content.get_media!(media_id)

    {:ok, :detached} = Content.detach_media_from_entity(biennale, media)

    current_media_links = Content.list_entity_media_links_for_entity(biennale)
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
    biennale = socket.assigns.biennale
    media_ids = Enum.map(media_ids, &String.to_integer/1)
    {:ok, :reordered} = Content.reorder_entity_media(biennale, media_ids)

    current_media_links = Content.list_entity_media_links_for_entity(biennale)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("update_media_link", %{"media_id" => media_id, "metadata" => metadata}, socket) do
    biennale = socket.assigns.biennale
    media = %Media{id: String.to_integer(media_id)}
    {:ok, :updated} = Content.update_entity_media_link(biennale, media, metadata)

    current_media_links = Content.list_entity_media_links_for_entity(biennale)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("save", params, socket) do
    biennale_params = extract_biennale_params(params)
    save_biennale(socket, socket.assigns.action, biennale_params)
  end

  defp save_biennale(socket, :edit, biennale_params) do
    changeset = BiennaleForm.changeset(socket.assigns.form.source.data, biennale_params)

    if changeset.valid? do
      attrs = biennale_attrs_from_form(changeset)

      case Content.update_biennale(socket.assigns.biennale, attrs) do
        {:ok, biennale} ->
          notify_parent({:saved, biennale})

          {:noreply,
           socket
           |> put_flash(:info, "Biennale updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = entity_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update biennale")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :biennale)
           )
           |> assign(:entity_changeset, entity_changeset)}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :biennale))}
    end
  end

  defp save_biennale(socket, :new, biennale_params) do
    changeset = BiennaleForm.changeset(socket.assigns.form.source.data, biennale_params)

    if changeset.valid? do
      attrs = biennale_attrs_from_form(changeset)

      case Content.create_biennale(attrs) do
        {:ok, biennale} ->
          notify_parent({:saved, biennale})

          {:noreply,
           socket
           |> put_flash(:info, "Biennale created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = entity_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create biennale")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :biennale)
           )
           |> assign(:entity_changeset, entity_changeset)}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :biennale))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp extract_biennale_params(%{"biennale" => p}) when is_map(p), do: p
  defp extract_biennale_params(%{"entity" => p}) when is_map(p), do: p
  defp extract_biennale_params(_), do: %{}

  defp biennale_form_attrs(%Content.Entity{fields: fields} = entity) when is_map(fields) do
    %{
      year: map_get_int(fields, "year"),
      theme: Map.get(fields, "theme"),
      statement: Map.get(fields, "statement"),
      description: Map.get(fields, "description"),
      start_date: map_get_date(fields, "start_date"),
      end_date: map_get_date(fields, "end_date"),
      visible: true,
      template: entity.template || "default",
      show_program: Map.get(fields, "show_program", true)
    }
  end

  defp biennale_form_attrs(%Content.Entity{}), do: %{visible: true, show_program: true}

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

  defp biennale_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    %{
      year: form.year,
      theme: form.theme,
      statement: form.statement,
      description: form.description,
      start_date: form.start_date,
      end_date: form.end_date,
      visible: form.visible,
      template: form.template,
      show_program: form.show_program
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
