defmodule MykonosBiennaleWeb.Admin.ProjectLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Media, Entity}
  alias Ecto.Changeset

  defmodule ProjectForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :title, :string
      field :description, :string
      field :statement, :string
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [:title, :description, :statement, :visible])
      |> validate_required([:title])
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
        id="project-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:description]} type="textarea" label="Description" rows="4" />
          <.input field={@form[:statement]} type="textarea" label="Statement" rows="4" />
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Project
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
            id="project-media-links"
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

        <%= if @project.id do %>
          <div class="mt-4 space-y-2">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Upload Images
            </label>
            <.live_file_input upload={@uploads.images} class="hidden" />
            <button
              type="button"
              onclick={"document.getElementById('project-form_images').click()"}
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
    </div>
    """
  end

  @impl true
  def update(%{project: project} = assigns, socket) do
    current_media_links =
      if project.id do
        Content.list_entity_media_links_for_entity(project)
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
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 20,
       max_file_size: 20_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_new(:form, fn ->
       changeset = ProjectForm.changeset(%ProjectForm{}, project_form_attrs(project))
       to_form(changeset, as: :project)
     end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    project_params = extract_project_params(params)

    changeset =
      socket.assigns.form.source.data
      |> ProjectForm.changeset(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :project))}
  end

  def handle_event("attach_media", %{"media_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_media", %{"media_id" => media_id}, socket) do
    project = socket.assigns.project

    if project.id do
      media = Content.get_media!(media_id)

      case Content.attach_media_to_entity(project, media) do
        {:ok, :attached} ->
          current_media_links = Content.list_entity_media_links_for_entity(project)
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
      {:noreply, put_flash(socket, :error, "Save the project first before attaching media")}
    end
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    project = socket.assigns.project
    media = Content.get_media!(media_id)

    {:ok, :detached} = Content.detach_media_from_entity(project, media)

    current_media_links = Content.list_entity_media_links_for_entity(project)
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
    project = socket.assigns.project
    media_ids = Enum.map(media_ids, &String.to_integer/1)
    {:ok, :reordered} = Content.reorder_entity_media(project, media_ids)

    current_media_links = Content.list_entity_media_links_for_entity(project)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("update_media_link", %{"media_id" => media_id, "metadata" => metadata}, socket) do
    project = socket.assigns.project
    media = %Media{id: String.to_integer(media_id)}
    {:ok, :updated} = Content.update_entity_media_link(project, media, metadata)

    current_media_links = Content.list_entity_media_links_for_entity(project)
    {:noreply, assign(socket, :current_media_links, current_media_links)}
  end

  def handle_event("save", params, socket) do
    project_params = extract_project_params(params)
    save_project(socket, socket.assigns.action, project_params)
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  def handle_event("save_uploads", _params, socket) do
    project = socket.assigns.project
    title = project.fields["title"] || "Untitled"

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
          caption: title
        }) do
          {:ok, media} ->
            Content.attach_media_to_entity(project, media)
            {:ok, media}

          {:error, _} = err ->
            err
        end
      end)

    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)

    current_media_links = Content.list_entity_media_links_for_entity(project)
    all_media = Content.list_media()
    attached_ids = Enum.map(current_media_links, & &1.media_id)
    available_media = Enum.reject(all_media, fn m -> m.id in attached_ids end)

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

    {:noreply,
     socket
     |> assign(:current_media_links, current_media_links)
     |> assign(:available_media, available_media)
     |> put_flash(flash_type, flash)}
  end

  defp handle_progress(:images, _entry, socket) do
    {:noreply, socket}
  end

  defp save_project(socket, :edit, project_params) do
    changeset = ProjectForm.changeset(socket.assigns.form.source.data, project_params)

    if changeset.valid? do
      attrs = project_attrs_from_form(changeset)

      case Content.update_project(socket.assigns.project, attrs) do
        {:ok, project} ->
          notify_parent({:saved, project})

          {:noreply,
           socket
           |> put_flash(:info, "Project updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update project")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :project)
           )}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :project))}
    end
  end

  defp save_project(socket, :new, project_params) do
    changeset = ProjectForm.changeset(socket.assigns.form.source.data, project_params)

    if changeset.valid? do
      attrs = project_attrs_from_form(changeset)

      case Content.create_project(attrs) do
        {:ok, project} ->
          notify_parent({:saved, project})

          {:noreply,
           socket
           |> put_flash(:info, "Project created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create project")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :project)
           )}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :project))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp extract_project_params(%{"project" => p}) when is_map(p), do: p
  defp extract_project_params(_), do: %{}

  defp project_form_attrs(%Content.Entity{fields: fields}) when is_map(fields) do
    %{
      title: Map.get(fields, "title"),
      description: Map.get(fields, "description"),
      statement: Map.get(fields, "statement"),
      visible: true
    }
  end

  defp project_form_attrs(%Content.Entity{}), do: %{visible: true}

  defp project_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    %{
      title: form.title,
      description: form.description,
      statement: form.statement
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
