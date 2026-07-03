defmodule MykonosBiennaleWeb.Admin.FilmLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, RelationshipType}
  alias Ecto.Changeset

  import Ecto.Query, warn: false

  @film_rel_slugs [
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

  @film_type_options [
    {"Short Film", "Short Film"},
    {"Video", "Video"},
    {"Dance", "Dance"},
    {"Animation", "Animation"},
    {"Documentary", "Documentary"}
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
      field :type, :string
      field :event_id, :string
      field :trailer_url, :string
      field :trailer_embed, :string
      field :screening_copy_url, :string
      field :save_and_more, :boolean, default: false
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
        :sub_by,
        :type,
        :event_id,
        :trailer_url,
        :trailer_embed,
        :screening_copy_url,
        :save_and_more
      ])
      |> validate_required([:title])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      data-theme="light"
      class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900 max-h-[85vh] overflow-y-auto"
    >
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="film-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <.input field={@form[:ref]} type="text" label="Ref" />
            <.input field={@form[:runtime]} type="text" label="Runtime (min)" />
            <.input field={@form[:year]} type="text" label="Year" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input
              field={@form[:type]}
              type="select"
              label="Film Type"
              options={@film_type_options}
              prompt="Select type"
            />
            <.input field={@form[:country]} type="text" label="Country" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:dir_by]} type="text" label="Director" />
            <.input field={@form[:sub_by]} type="text" label="Submitted by" />
          </div>

          <.input field={@form[:log_line]} type="text" label="Log Line" />
          <.input field={@form[:synopsis]} type="textarea" label="Synopsis" rows="4" />

          <div class="space-y-2">
            <label class="block text-sm font-semibold text-gray-900">Event (Screened At)</label>
            <select
              name={@form[:event_id].name}
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">No event</option>
              <%= for event <- @film_events do %>
                <option value={event.id} selected={@form[:event_id].value == to_string(event.id)}>
                  {field(event, "date")} {field(event, "title")}
                </option>
              <% end %>
            </select>
          </div>
        </div>

        <hr class="my-6 border-gray-200" />
        <h3 class="text-sm font-semibold text-gray-900 mb-3">Poster</h3>

        <%= if @poster_link do %>
          <div class="relative group bg-gray-50 rounded-lg overflow-hidden w-40 mb-3">
            <div class="aspect-[2/3] bg-gray-100 flex items-center justify-center">
              <%= if @poster_link.media.source_path do %>
                <img
                  src={MykonosBiennale.Uploads.media_url(@poster_link.media, size: "card")}
                  alt="Poster"
                  class="w-full h-full object-cover"
                />
              <% else %>
                <.icon name="hero-photo" class="w-8 h-8 text-gray-400" />
              <% end %>
            </div>
            <button
              type="button"
              phx-click="detach_poster"
              phx-target={@myself}
              class="absolute top-2 right-2 bg-red-600 text-white p-1 rounded opacity-0 group-hover:opacity-100 transition-opacity"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <div
          class="border-2 border-dashed border-gray-300 rounded-lg p-3 text-center hover:border-blue-500 transition-colors"
          phx-drop-target={@uploads.poster.ref}
        >
          <.live_file_input upload={@uploads.poster} class="hidden" />
          <button
            type="button"
            phx-click={JS.dispatch("click", to: "##{@uploads.poster.ref}")}
            class="text-blue-600 hover:text-blue-700 font-medium text-sm"
          >
            Upload poster
          </button>
          <p class="mt-1 text-xs text-gray-500">JPG, PNG, WEBP · 1 image max</p>
        </div>
        <%= for entry <- @uploads.poster.entries do %>
          <div class="flex items-center justify-between bg-gray-50 p-2 rounded mt-2">
            <div class="flex items-center gap-2">
              <.icon name="hero-document" class="w-4 h-4 text-gray-400" />
              <span class="text-sm text-gray-900">{entry.client_name}</span>
              <span class="text-xs text-gray-500">{format_bytes(entry.client_size)}</span>
            </div>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              phx-value-upload="poster"
              phx-target={@myself}
              class="text-red-600 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
        <%= for err <- upload_errors(@uploads.poster) do %>
          <p class="text-sm text-red-600">{error_to_string(err)}</p>
        <% end %>

        <hr class="my-6 border-gray-200" />
        <h3 class="text-sm font-semibold text-gray-900 mb-3">Stills &amp; Screenshots</h3>

        <%= if @still_links == [] do %>
          <p class="text-sm text-gray-500 mb-3">No stills uploaded yet</p>
        <% else %>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-3">
            <%= for link <- @still_links do %>
              <div class="relative group bg-gray-50 rounded-lg overflow-hidden">
                <div class="aspect-video bg-gray-100 flex items-center justify-center">
                  <%= if link.media.source_path do %>
                    <img
                      src={MykonosBiennale.Uploads.media_url(link.media, size: "thumb")}
                      alt={link.media.caption || "Still"}
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
                  class="absolute top-1 right-1 bg-red-600 text-white p-1 rounded opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <.icon name="hero-x-mark" class="w-3 h-3" />
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <div
          class="border-2 border-dashed border-gray-300 rounded-lg p-3 text-center hover:border-blue-500 transition-colors"
          phx-drop-target={@uploads.stills.ref}
        >
          <.live_file_input upload={@uploads.stills} class="hidden" />
          <button
            type="button"
            phx-click={JS.dispatch("click", to: "##{@uploads.stills.ref}")}
            class="text-blue-600 hover:text-blue-700 font-medium text-sm"
          >
            Upload stills
          </button>
          <p class="mt-1 text-xs text-gray-500">JPG, PNG, WEBP · up to 10 images</p>
        </div>
        <%= for entry <- @uploads.stills.entries do %>
          <div class="flex items-center justify-between bg-gray-50 p-2 rounded mt-2">
            <div class="flex items-center gap-2">
              <.icon name="hero-document" class="w-4 h-4 text-gray-400" />
              <span class="text-sm text-gray-900">{entry.client_name}</span>
              <span class="text-xs text-gray-500">{format_bytes(entry.client_size)}</span>
            </div>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              phx-value-upload="stills"
              phx-target={@myself}
              class="text-red-600 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
        <%= for err <- upload_errors(@uploads.stills) do %>
          <p class="text-sm text-red-600">{error_to_string(err)}</p>
        <% end %>

        <hr class="my-6 border-gray-200" />
        <h3 class="text-sm font-semibold text-gray-900 mb-3">Trailer</h3>

        <%= if @trailer_link do %>
          <div class="flex items-center justify-between bg-gray-50 p-3 rounded-lg mb-3">
            <div class="flex items-center gap-3">
              <.icon name="hero-video-camera" class="w-5 h-5 text-blue-500" />
              <span class="text-sm font-medium text-gray-900">
                {@trailer_link.media.caption || "Trailer video"}
              </span>
            </div>
            <button
              type="button"
              phx-click="detach_trailer"
              phx-target={@myself}
              class="text-red-600 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <div
          class="border-2 border-dashed border-gray-300 rounded-lg p-3 text-center hover:border-blue-500 transition-colors mb-3"
          phx-drop-target={@uploads.trailer_video.ref}
        >
          <.live_file_input upload={@uploads.trailer_video} class="hidden" />
          <button
            type="button"
            phx-click={JS.dispatch("click", to: "##{@uploads.trailer_video.ref}")}
            class="text-blue-600 hover:text-blue-700 font-medium text-sm"
          >
            Upload trailer video
          </button>
          <p class="mt-1 text-xs text-gray-500">MP4, MOV, WEBM · 1 video max · up to 500MB</p>
        </div>
        <%= for entry <- @uploads.trailer_video.entries do %>
          <div class="flex items-center justify-between bg-gray-50 p-2 rounded mb-3">
            <div class="flex items-center gap-2">
              <.icon name="hero-video-camera" class="w-4 h-4 text-blue-400" />
              <span class="text-sm text-gray-900">{entry.client_name}</span>
              <span class="text-xs text-gray-500">{format_bytes(entry.client_size)}</span>
            </div>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              phx-value-upload="trailer_video"
              phx-target={@myself}
              class="text-red-600 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
        <%= for err <- upload_errors(@uploads.trailer_video) do %>
          <p class="text-sm text-red-600">{error_to_string(err)}</p>
        <% end %>

        <.input field={@form[:trailer_url]} type="text" label="Trailer URL" placeholder="https://..." />
        <.input
          field={@form[:trailer_embed]}
          type="textarea"
          label="Trailer Embed"
          rows="2"
          placeholder="<iframe ...>"
        />

        <hr class="my-6 border-gray-200" />
        <h3 class="text-sm font-semibold text-gray-900 mb-3">Screening Copy</h3>

        <%= if @screening_copy_link do %>
          <div class="flex items-center justify-between bg-gray-50 p-3 rounded-lg mb-3">
            <div class="flex items-center gap-3">
              <.icon name="hero-film" class="w-5 h-5 text-purple-500" />
              <span class="text-sm font-medium text-gray-900">
                {@screening_copy_link.media.caption || "Screening copy"}
              </span>
            </div>
            <button
              type="button"
              phx-click="detach_screening_copy"
              phx-target={@myself}
              class="text-red-600 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <div
          class="border-2 border-dashed border-gray-300 rounded-lg p-3 text-center hover:border-blue-500 transition-colors mb-3"
          phx-drop-target={@uploads.screening_copy_video.ref}
        >
          <.live_file_input upload={@uploads.screening_copy_video} class="hidden" />
          <button
            type="button"
            phx-click={JS.dispatch("click", to: "##{@uploads.screening_copy_video.ref}")}
            class="text-blue-600 hover:text-blue-700 font-medium text-sm"
          >
            Upload screening copy
          </button>
          <p class="mt-1 text-xs text-gray-500">MP4, MOV, WEBM · 1 video max · up to 2GB</p>
        </div>
        <%= for entry <- @uploads.screening_copy_video.entries do %>
          <div class="flex items-center justify-between bg-gray-50 p-2 rounded mb-3">
            <div class="flex items-center gap-2">
              <.icon name="hero-film" class="w-4 h-4 text-purple-400" />
              <span class="text-sm text-gray-900">{entry.client_name}</span>
              <span class="text-xs text-gray-500">{format_bytes(entry.client_size)}</span>
            </div>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              phx-value-upload="screening_copy_video"
              phx-target={@myself}
              class="text-red-600 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
        <%= for err <- upload_errors(@uploads.screening_copy_video) do %>
          <p class="text-sm text-red-600">{error_to_string(err)}</p>
        <% end %>

        <.input
          field={@form[:screening_copy_url]}
          type="text"
          label="Screening Copy URL"
          placeholder="https://..."
        />

        <div class="mt-6 flex items-center justify-between gap-x-6">
          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              id="save_and_more"
              name="film[save_and_more]"
              value="true"
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="save_and_more" class="text-sm text-gray-700">Save &amp; Add Another</label>
          </div>
          <div class="flex items-center gap-x-4">
            <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
              Cancel
            </.link>
            <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
              Save Film
            </button>
          </div>
        </div>
      </.form>

      <%= if @film.id do %>
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
      <% end %>
    </div>
    """
  end

  @impl true
  def update(%{film: film} = assigns, socket) do
    all_media_links =
      if film.id do
        Content.list_entity_media_links_for_entity(film)
      else
        []
      end

    {poster_links, non_poster_links} =
      Enum.split_with(all_media_links, fn link ->
        meta = link.metadata || %{}
        meta["is_poster"] == true or meta["role"] == "poster"
      end)

    poster_link = List.first(poster_links)

    {trailer_links, rest_links} =
      Enum.split_with(non_poster_links, fn link ->
        meta = link.metadata || %{}
        meta["role"] == "trailer"
      end)

    trailer_link = List.first(trailer_links)

    {screening_copy_links, still_links} =
      Enum.split_with(rest_links, fn link ->
        meta = link.metadata || %{}
        meta["role"] == "screening_copy"
      end)

    screening_copy_link = List.first(screening_copy_links)

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

    film_events = Content.list_film_events()

    current_event_id =
      if film.id do
        event_rels = Content.list_film_linked_events(film)

        case List.first(event_rels) do
          nil -> nil
          rel -> to_string(rel.object_id)
        end
      else
        Map.get(assigns, :default_event_id)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:film_rel_slugs, @film_rel_slugs)
     |> assign(:film_type_options, @film_type_options)
     |> assign(:poster_link, poster_link)
     |> assign(:still_links, still_links)
     |> assign(:trailer_link, trailer_link)
     |> assign(:screening_copy_link, screening_copy_link)
     |> assign(:linked_relationships, linked_relationships)
     |> assign(:available_participants, available_participants)
     |> assign(:film_events, film_events)
     |> assign_new(:form, fn ->
       attrs = film_form_attrs(film) |> Map.put(:event_id, current_event_id)
       changeset = FilmForm.changeset(%FilmForm{}, attrs)
       to_form(changeset, as: :film)
     end)
     |> allow_upload(:poster,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> allow_upload(:stills,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 10,
       max_file_size: 10_000_000
     )
     |> allow_upload(:trailer_video,
       accept: ~w(.mp4 .mov .webm video/mp4 video/quicktime video/webm),
       max_entries: 1,
       max_file_size: 500_000_000
     )
     |> allow_upload(:screening_copy_video,
       accept: ~w(.mp4 .mov .webm video/mp4 video/quicktime video/webm),
       max_entries: 1,
       max_file_size: 2_000_000_000
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

  def handle_event("cancel-upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_atom(upload_name), ref)}
  end

  def handle_event("detach_poster", _params, socket) do
    film = socket.assigns.film
    poster_link = socket.assigns.poster_link

    if poster_link do
      media = Content.get_media!(poster_link.media_id)
      {:ok, :detached} = Content.detach_media_from_entity(film, media)
    end

    {:noreply, assign(socket, :poster_link, nil) |> put_flash(:info, "Poster detached")}
  end

  def handle_event("detach_trailer", _params, socket) do
    film = socket.assigns.film
    trailer_link = socket.assigns.trailer_link

    if trailer_link do
      media = Content.get_media!(trailer_link.media_id)
      {:ok, :detached} = Content.detach_media_from_entity(film, media)
    end

    {:noreply, assign(socket, :trailer_link, nil) |> put_flash(:info, "Trailer detached")}
  end

  def handle_event("detach_screening_copy", _params, socket) do
    film = socket.assigns.film
    screening_copy_link = socket.assigns.screening_copy_link

    if screening_copy_link do
      media = Content.get_media!(screening_copy_link.media_id)
      {:ok, :detached} = Content.detach_media_from_entity(film, media)
    end

    {:noreply,
     assign(socket, :screening_copy_link, nil) |> put_flash(:info, "Screening copy detached")}
  end

  def handle_event("detach_media", %{"media-id" => media_id}, socket) do
    film = socket.assigns.film
    media = Content.get_media!(media_id)
    {:ok, :detached} = Content.detach_media_from_entity(film, media)
    still_links = Enum.reject(socket.assigns.still_links, fn l -> l.media_id == media.id end)

    {:noreply, assign(socket, :still_links, still_links) |> put_flash(:info, "Still detached")}
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
      event_id = Changeset.get_field(changeset, :event_id)
      save_and_more = Changeset.get_field(changeset, :save_and_more, false)

      save_film(socket, socket.assigns.action, attrs, event_id, save_and_more)
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :film))}
    end
  end

  defp save_film(socket, :new, attrs, event_id, save_and_more) do
    case Content.Film.create(attrs) do
      {:ok, film} ->
        process_uploads(socket, film)
        maybe_attach_event(film, event_id)
        send(self(), {__MODULE__, {:saved, film}})

        if save_and_more do
          {:noreply,
           socket
           |> put_flash(:info, "Film created — add another")
           |> push_patch(to: "/admin/films/new?event_id=#{event_id || ""}")}
        else
          {:noreply,
           socket |> put_flash(:info, "Film created") |> push_patch(to: socket.assigns.patch)}
        end

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Could not create film")}
    end
  end

  defp save_film(socket, :edit, attrs, event_id, save_and_more) do
    case Content.Film.update(socket.assigns.film, attrs) do
      {:ok, film} ->
        process_uploads(socket, film)
        maybe_attach_event(film, event_id)
        send(self(), {__MODULE__, {:saved, film}})

        if save_and_more do
          {:noreply,
           socket
           |> put_flash(:info, "Film updated — add another")
           |> push_patch(to: "/admin/films/new?event_id=#{event_id || ""}")}
        else
          {:noreply,
           socket |> put_flash(:info, "Film updated") |> push_patch(to: socket.assigns.patch)}
        end

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Could not update film")}
    end
  end

  defp process_uploads(socket, film) do
    consume_upload(film, socket, :poster, %{role: "poster", is_poster: true})
    consume_upload(film, socket, :stills, %{role: "still"})
    consume_upload(film, socket, :trailer_video, %{role: "trailer"})
    consume_upload(film, socket, :screening_copy_video, %{role: "screening_copy"})
  end

  defp consume_upload(film, socket, upload_key, metadata) do
    uploaded_files =
      consume_uploaded_entries(socket, upload_key, fn %{path: path}, entry ->
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
          caption: Path.basename(original_name, Path.extname(original_name)),
          source_type: "upload",
          source_path: path,
          mime_type: mime_type,
          original_name: original_name
        })

      Content.attach_media_to_entity(film, media, metadata: metadata)
    end
  end

  defp maybe_attach_event(_film, ""), do: :ok
  defp maybe_attach_event(_film, nil), do: :ok

  defp maybe_attach_event(film, event_id) do
    existing = Content.list_film_linked_events(film)
    existing_ids = Enum.map(existing, &to_string(&1.object_id))

    for rel <- existing, to_string(rel.object_id) != event_id do
      Content.detach_event_from_film(film, rel.object_id)
    end

    if event_id not in existing_ids do
      event = Content.get_event!(event_id)
      Content.attach_event_to_film(film, event)
    end

    :ok
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp extract_film_params(%{"film" => p}) when is_map(p), do: p
  defp extract_film_params(_), do: %{}

  defp film_form_attrs(%Entity{identity: identity, fields: fields, type: type})
       when is_map(fields) do
    %{
      title: identity,
      ref: Map.get(fields, "ref"),
      runtime: to_string(Map.get(fields, "runtime") || ""),
      country: Map.get(fields, "country"),
      log_line: Map.get(fields, "log_line"),
      synopsis: Map.get(fields, "synopsis"),
      year: Map.get(fields, "year"),
      dir_by: Map.get(fields, "dir_by"),
      sub_by: Map.get(fields, "sub_by"),
      type: type || "Short Film",
      trailer_url: Map.get(fields, "trailer_url"),
      trailer_embed: Map.get(fields, "trailer_embed"),
      screening_copy_url: Map.get(fields, "screening_copy_url")
    }
  end

  defp film_form_attrs(%Entity{identity: identity, type: type}) do
    %{title: identity, type: type || "Short Film"}
  end

  defp film_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    runtime =
      case form.runtime do
        nil -> nil
        "" -> nil
        v -> String.to_integer(v)
      end

    %{
      title: form.title,
      ref: form.ref,
      runtime: runtime,
      country: form.country,
      log_line: form.log_line,
      synopsis: form.synopsis,
      year: form.year,
      dir_by: form.dir_by,
      sub_by: form.sub_by,
      type: form.type,
      trailer_url: form.trailer_url,
      trailer_embed: form.trailer_embed,
      screening_copy_url: form.screening_copy_url
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Enum.into(%{})
  end

  defp field(%Entity{fields: fields}, key) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key))
  end

  defp field(_, _), do: nil
end
