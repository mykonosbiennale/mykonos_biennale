defmodule MykonosBiennaleWeb.Admin.MediaLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Upload an image/video, link to a URL, or embed HTML code</:subtitle>
      </.header>

      <.form
        for={@form}
        id="media-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:caption]} type="text" label="Caption" />

        <.input
          field={@form[:source_type]}
          type="select"
          label="Source Type"
          options={[{"Upload File", "upload"}, {"External URL", "url"}, {"Embed Code", "embed"}]}
          prompt="Choose source type"
        />

        <%= if @form[:source_type].value == "upload" do %>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-semibold text-gray-900 dark:text-gray-100 mb-2">
                Upload File
              </label>
              <div
                class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg p-6 text-center hover:border-blue-500 transition-colors"
                phx-drop-target={@uploads.media_file.ref}
              >
                <.live_file_input upload={@uploads.media_file} class="hidden" />
                <button
                  type="button"
                  phx-click={JS.dispatch("click", to: "##{@uploads.media_file.ref}")}
                  class="text-blue-600 hover:text-blue-700 font-medium"
                >
                  Click to upload or drag and drop
                </button>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  PNG, JPG, GIF, MP4, WEBM up to 10MB
                </p>
              </div>
            </div>

            <%= for entry <- @uploads.media_file.entries do %>
              <div class="flex items-center justify-between bg-gray-50 dark:bg-gray-800 p-3 rounded">
                <div class="flex items-center gap-3">
                  <.icon name="hero-document" class="w-5 h-5 text-gray-400" />
                  <div
                    data-theme="light"
                    class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900"
                  >
                    <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {entry.client_name}
                    </p>
                    <p class="text-xs text-gray-500">
                      {format_bytes(entry.client_size)}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  phx-target={@myself}
                  class="text-red-600 hover:text-red-700"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>

              <%= for err <- upload_errors(@uploads.media_file, entry) do %>
                <p class="text-sm text-red-600">{error_to_string(err)}</p>
              <% end %>
            <% end %>

            <%= for err <- upload_errors(@uploads.media_file) do %>
              <p class="text-sm text-red-600">{error_to_string(err)}</p>
            <% end %>
          </div>
        <% end %>

        <%= if @form[:source_type].value == "url" do %>
          <.input
            field={@form[:source_url]}
            type="url"
            label="External URL"
            placeholder="https://example.com/image.jpg"
          />
        <% end %>

        <%= if @form[:source_type].value == "embed" do %>
          <.input
            field={@form[:source_embed]}
            type="textarea"
            label="Embed Code"
            placeholder="<iframe src='https://www.youtube.com/embed/...' ...></iframe>"
            rows="6"
          />
        <% end %>

        <.input field={@form[:alt_text]} type="text" label="Alt Text (for accessibility)" />

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.button
            phx-disable-with="Saving..."
            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg"
          >
            Save Media
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{media: media} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Content.change_media(media))
     end)
     |> allow_upload(:media_file,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .webm .webp),
       max_entries: 1,
       max_file_size: 100_000_000
     )}
  end

  @impl true
  def handle_event("validate", %{"media" => media_params}, socket) do
    changeset = Content.change_media(socket.assigns.media, media_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media_file, ref)}
  end

  def handle_event("save", %{"media" => media_params}, socket) do
    save_media(socket, socket.assigns.action, media_params)
  end

  defp save_media(socket, :edit, media_params) do
    media_params = maybe_add_uploaded_file(socket, media_params)

    case Content.update_media(socket.assigns.media, media_params) do
      {:ok, media} ->
        notify_parent({:saved, media})

        {:noreply,
         socket
         |> put_flash(:info, "Media updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_media(socket, :new, media_params) do
    media_params = maybe_add_uploaded_file(socket, media_params)

    case Content.create_media(media_params) do
      {:ok, media} ->
        notify_parent({:saved, media})

        {:noreply,
         socket
         |> put_flash(:info, "Media created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp maybe_add_uploaded_file(socket, media_params) do
    if media_params["source_type"] == "upload" do
      uploaded_files =
        consume_uploaded_entries(socket, :media_file, fn %{path: path}, entry ->
          ext = Path.extname(entry.client_name)
          filename = "#{Ecto.UUID.generate()}#{ext}"
          dest = MykonosBiennale.Uploads.uploads_path(filename)

          MykonosBiennale.Uploads.ensure_uploads_dir()

          File.cp!(path, dest)

          {:ok, %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
        end)

      case uploaded_files do
        [%{path: path, mime_type: mime_type, original_name: original_name}] ->
          media_params
          |> Map.put("source_path", path)
          |> Map.put("mime_type", mime_type)
          |> Map.put("original_name", original_name)

        [] ->
          media_params
      end
    else
      media_params
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

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
end
