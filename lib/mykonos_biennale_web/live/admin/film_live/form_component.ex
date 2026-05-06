defmodule MykonosBiennaleWeb.Admin.FilmLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, RelationshipType}
  alias Ecto.Changeset

  @film_rel_slugs [
    {"Screened At", "screened_at"},
    {"Directed", "directed"},
    {"Produced", "produced"},
    {"Screenwrote", "screenwrote"},
    {"Acted In", "acted_in"},
    {"Composed For", "composed_for"},
    {"Shot", "shot"},
    {"Edited", "edited"},
    {"Exec Produced", "exec_produced"},
    {"Participated In", "participated_in"}
  ]

  defmodule FilmForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :title, :string
      field :ref, :string
      field :runtime, :string
      field :country, :string
      field :log_line, :string
      field :synopsis, :string
      field :year, :string
      field :dir_by, :string
      field :sub_by, :string
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [
        :title,
        :ref,
        :runtime,
        :country,
        :log_line,
        :synopsis,
        :year,
        :dir_by,
        :sub_by
      ])
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
        id="film-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <.input field={@form[:ref]} type="text" label="Ref" />
            <.input field={@form[:runtime]} type="text" label="Runtime (min)" />
            <.input field={@form[:year]} type="text" label="Year" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:country]} type="text" label="Country" />
            <.input field={@form[:dir_by]} type="text" label="Director" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:sub_by]} type="text" label="Submitted by" />
            <.input field={@form[:log_line]} type="text" label="Log Line" />
          </div>

          <.input field={@form[:synopsis]} type="textarea" label="Synopsis" rows="4" />

          <div class="space-y-2">
            <label class="block text-sm font-semibold text-gray-900">Poster / Images</label>

            <%= if @current_media_links == [] do %>
              <p class="text-sm text-gray-500 mb-4">No images uploaded yet</p>
            <% else %>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-4">
                <div
                  :for={link <- @current_media_links}
                  class="relative group bg-gray-50 rounded-lg overflow-hidden"
                >
                  <div class="aspect-video bg-gray-100 flex items-center justify-center">
                    <%= if link.media.source_path do %>
                      <img
                        src={"/uploads/#{link.media.source_path}"}
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
              phx-drop-target={@uploads.film_image.ref}
            >
              <.live_file_input upload={@uploads.film_image} class="hidden" />
              <button
                type="button"
                phx-click={JS.dispatch("click", to: "##{@uploads.film_image.ref}")}
                class="text-blue-600 hover:text-blue-700 font-medium text-sm"
              >
                Click to upload or drag and drop
              </button>
              <p class="mt-1 text-xs text-gray-500">JPG, PNG, WEBP up to 10MB</p>
            </div>

            <%= for entry <- @uploads.film_image.entries do %>
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

            <%= for err <- upload_errors(@uploads.film_image) do %>
              <p class="text-sm text-red-600">{error_to_string(err)}</p>
            <% end %>
          </div>
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Film
          </button>
        </div>
      </.form>

      <div class="mt-6">
        <label class="block text-sm font-semibold text-gray-900 mb-2">Add Relationship</label>
        <form phx-submit="attach_relationship" phx-target={@myself}>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <select
              name="relationship_slug"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">Relationship type...</option>
              <%= for {label, slug} <- @film_rel_slugs do %>
                <option value={slug}>{label}</option>
              <% end %>
            </select>
            <select
              name="participant_id"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">Participant...</option>
              <%= for p <- @available_participants do %>
                <option value={p.id}>
                  {field(p, "name") || "#{field(p, "first_name")} #{field(p, "last_name")}"}
                </option>
              <% end %>
            </select>
            <div class="flex gap-2">
              <input
                type="text"
                name="role"
                placeholder="Role"
                class="flex-1 rounded-lg border-gray-300 bg-white text-gray-900 px-3 py-2"
              />
              <button
                type="submit"
                class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700"
              >
                Add
              </button>
            </div>
          </div>
        </form>
      </div>

      <div class="mt-6">
        <label class="block text-sm font-semibold text-gray-900 mb-2">Current Relationships</label>
        <%= if @linked_relationships == [] do %>
          <p class="text-sm text-gray-500">No relationships</p>
        <% else %>
          <div class="space-y-2">
            <%= for rel <- @linked_relationships do %>
              <div class="flex items-center justify-between bg-gray-50 p-3 rounded-lg">
                <div class="flex items-center gap-3">
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                    {rel.relationship_type.slug}
                  </span>
                  <span class="text-sm font-medium text-gray-900">
                    {field(rel.object, "name") ||
                      "#{field(rel.object, "first_name")} #{field(rel.object, "last_name")}"}
                  </span>
                  <%= if rel.fields["roles"] do %>
                    <span class="text-xs text-gray-500">({rel.fields["roles"]})</span>
                  <% end %>
                </div>
                <button
                  type="button"
                  phx-click="detach_relationship"
                  phx-value-rel-id={rel.id}
                  phx-target={@myself}
                  class="text-red-600 hover:text-red-700"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{film: film} = assigns, socket) do
    current_media_links =
      if film.id do
        Content.list_entity_media_links_for_entity(film)
      else
        []
      end

    linked_relationships =
      if film.id do
        Content.Film.list_relationships(film)
      else
        []
      end

    all_participants = Content.list_participants()
    linked_participant_ids = Enum.map(linked_relationships, & &1.object_id)

    available_participants =
      Enum.reject(all_participants, fn p -> p.id in linked_participant_ids end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:film_rel_slugs, @film_rel_slugs)
     |> assign(:current_media_links, current_media_links)
     |> assign(:linked_relationships, linked_relationships)
     |> assign(:available_participants, available_participants)
     |> assign_new(:form, fn ->
       changeset = FilmForm.changeset(%FilmForm{}, film_form_attrs(film))
       to_form(changeset, as: :film)
     end)
     |> allow_upload(:film_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 10,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_event("validate", params, socket) do
    film_params = extract_film_params(params)

    changeset =
      socket.assigns.form.source.data
      |> FilmForm.changeset(film_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :film))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :film_image, ref)}
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    film = socket.assigns.film
    media = Content.get_media!(media_id)
    {:ok, :detached} = Content.detach_media_from_entity(film, media)
    current_media_links = Content.list_entity_media_links_for_entity(film)

    {:noreply,
     assign(socket, :current_media_links, current_media_links)
     |> put_flash(:info, "Media detached")}
  end

  def handle_event(
        "attach_relationship",
        %{"relationship_slug" => "", "participant_id" => _},
        socket
      ) do
    {:noreply, socket}
  end

  def handle_event(
        "attach_relationship",
        %{"participant_id" => "", "relationship_slug" => _},
        socket
      ) do
    {:noreply, socket}
  end

  def handle_event(
        "attach_relationship",
        %{"relationship_slug" => slug, "participant_id" => participant_id, "role" => role},
        socket
      ) do
    film = socket.assigns.film

    if film.id do
      rt = Repo.get_by!(RelationshipType, slug: slug)
      participant = Content.get_participant!(participant_id)
      fields = if role != "", do: %{"roles" => role}, else: %{}

      case Content.create_relationship(%{
             slug: slug,
             label: rt.label,
             subject_id: film.id,
             object_id: participant.id,
             fields: fields
           }) do
        {:ok, _} ->
          linked_relationships = Content.Film.list_relationships(film)
          linked_participant_ids = Enum.map(linked_relationships, & &1.object_id)

          available_participants =
            Enum.reject(Content.list_participants(), fn p -> p.id in linked_participant_ids end)

          {:noreply,
           socket
           |> assign(:linked_relationships, linked_relationships)
           |> assign(:available_participants, available_participants)
           |> put_flash(:info, "Relationship added")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not add relationship: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the film first")}
    end
  end

  def handle_event("detach_relationship", %{"rel-id" => rel_id}, socket) do
    rel = Repo.get!(Content.Relationship, String.to_integer(rel_id))
    {:ok, _} = Content.delete_relationship(rel)
    film = socket.assigns.film
    linked_relationships = Content.Film.list_relationships(film)
    linked_participant_ids = Enum.map(linked_relationships, & &1.object_id)

    available_participants =
      Enum.reject(Content.list_participants(), fn p -> p.id in linked_participant_ids end)

    {:noreply,
     socket
     |> assign(:linked_relationships, linked_relationships)
     |> assign(:available_participants, available_participants)
     |> put_flash(:info, "Relationship removed")}
  end

  def handle_event("save", params, socket) do
    film_params = extract_film_params(params)
    changeset = FilmForm.changeset(socket.assigns.form.source.data, film_params)

    if changeset.valid? do
      attrs = film_attrs_from_form(changeset)

      case Content.Film.update(socket.assigns.film, attrs) do
        {:ok, film} ->
          maybe_upload_images(socket, film)
          send(self(), {__MODULE__, {:saved, film}})

          {:noreply,
           socket |> put_flash(:info, "Film updated") |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "Could not update film")}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :film))}
    end
  end

  defp maybe_upload_images(socket, film) do
    uploaded_files =
      consume_uploaded_entries(socket, :film_image, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = Path.join(["priv", "static", "uploads", filename])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, %{path: filename, mime_type: entry.client_type}}
      end)

    for %{path: path, mime_type: mime_type} <- uploaded_files do
      {:ok, media} =
        Content.create_media(%{
          caption: Path.basename(path, Path.extname(path)),
          source_type: "upload",
          source_path: path,
          mime_type: mime_type
        })

      Content.attach_media_to_entity(film, media)
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
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp extract_film_params(%{"film" => p}) when is_map(p), do: p
  defp extract_film_params(_), do: %{}

  defp film_form_attrs(%Entity{fields: fields}) when is_map(fields) do
    %{
      title: fields["title"] || Map.get(fields, "import_slug"),
      ref: fields["ref"],
      runtime: to_string(fields["runtime"] || ""),
      country: fields["country"],
      log_line: fields["log_line"],
      synopsis: fields["synopsis"],
      year: fields["year"],
      dir_by: fields["dir_by"],
      sub_by: fields["sub_by"]
    }
  end

  defp film_form_attrs(%Entity{}), do: %{}

  defp film_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)
    runtime = if form.runtime != "", do: String.to_integer(form.runtime), else: nil

    %{
      title: form.title,
      ref: form.ref,
      runtime: runtime,
      country: form.country,
      log_line: form.log_line,
      synopsis: form.synopsis,
      year: form.year,
      dir_by: form.dir_by,
      sub_by: form.sub_by
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp field(%Entity{fields: fields}, key) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key))
  end

  defp field(_, _), do: nil
end
