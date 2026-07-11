defmodule MykonosBiennaleWeb.Admin.ParticipantLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias Ecto.Changeset

  @social_platforms [
    "Instagram",
    "Twitter/X",
    "Facebook",
    "LinkedIn",
    "YouTube",
    "TikTok",
    "Vimeo",
    "Pinterest",
    "Threads",
    "Other"
  ]

  defmodule ParticipantForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :first_name, :string
      field :last_name, :string
      field :name, :string
      field :country, :string
      field :email, :string
      field :phone, :string
      field :website, :string
      field :bio, :string
      field :statement, :string
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [
        :first_name,
        :last_name,
        :name,
        :country,
        :email,
        :phone,
        :website,
        :bio,
        :statement,
        :visible
      ])
      |> validate_required([:name])
      |> auto_name()
    end

    defp auto_name(changeset) do
      first = get_field(changeset, :first_name) || ""
      last = get_field(changeset, :last_name) || ""
      name = get_field(changeset, :name) || ""
      auto = String.trim("#{first} #{last}")

      cond do
        name == "" and auto != "" ->
          put_change(changeset, :name, auto)

        name == "" ->
          changeset

        true ->
          changeset
      end
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
        id="participant-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:name]} type="text" label="Name" required />

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:first_name]} type="text" label="First Name" />
            <.input field={@form[:last_name]} type="text" label="Last Name" />
          </div>

          <.input
            field={@form[:country]}
            type="select"
            label="Country"
            options={country_options()}
            prompt="Select country"
          />

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input field={@form[:email]} type="email" label="Email" />
            <.input field={@form[:phone]} type="tel" label="Phone" />
          </div>

          <.input field={@form[:website]} type="url" label="Website" placeholder="https://" />

          <div class="space-y-3">
            <label class="block text-sm font-semibold text-gray-900">
              Social Media
            </label>

            <%= for {sm, i} <- Enum.with_index(@social_media_entries) do %>
              <div class="flex items-start gap-2">
                <div class="flex-1 grid grid-cols-[140px_1fr] gap-2">
                  <select
                    name={"participant[social_media][#{i}][platform]"}
                    class="rounded-lg border-gray-300 bg-white text-gray-900 text-sm"
                  >
                    <option value="">Platform...</option>
                    <%= for platform <- @social_platforms do %>
                      <option value={platform} selected={sm["platform"] == platform}>
                        {platform}
                      </option>
                    <% end %>
                  </select>
                  <input
                    type="text"
                    name={"participant[social_media][#{i}][handle]"}
                    value={sm["handle"] || ""}
                    placeholder="@handle"
                    class="flex-1 rounded-lg border-gray-300 bg-white text-gray-900 text-sm px-3 py-2"
                  />
                </div>
                <button
                  type="button"
                  phx-click="remove_social_media"
                  phx-value-index={i}
                  phx-target={@myself}
                  class="text-red-500 hover:text-red-700 mt-2"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
            <% end %>

            <button
              type="button"
              phx-click="add_social_media"
              phx-target={@myself}
              class="text-sm text-blue-600 hover:text-blue-700 font-medium"
            >
              + Add Social Media Handle
            </button>
          </div>

          <div class="space-y-2">
            <label class="block text-sm font-semibold text-gray-900">
              Headshot
            </label>

            <%= if @headshot_media do %>
              <div class="relative group inline-block">
                <img
                  src={headshot_url(@headshot_media)}
                  alt={field(@participant, "name")}
                  class="w-24 h-24 rounded-full object-cover border-2 border-purple-500/30"
                />
                <button
                  type="button"
                  phx-click="remove_headshot"
                  phx-target={@myself}
                  class="absolute -top-1 -right-1 bg-red-600 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <.icon name="hero-x-mark" class="w-3 h-3" />
                </button>
              </div>
            <% else %>
              <div
                class="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center hover:border-blue-500 transition-colors"
                phx-drop-target={@uploads.headshot.ref}
              >
                <.live_file_input upload={@uploads.headshot} class="hidden" />
                <button
                  type="button"
                  phx-click={JS.dispatch("click", to: "##{@uploads.headshot.ref}")}
                  class="text-blue-600 hover:text-blue-700 font-medium text-sm"
                >
                  Click to upload or drag and drop
                </button>
                <p class="mt-1 text-xs text-gray-500">
                  JPG, PNG, WEBP up to 10MB
                </p>
              </div>

              <%= for entry <- @uploads.headshot.entries do %>
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

              <%= for err <- upload_errors(@uploads.headshot) do %>
                <p class="text-sm text-red-600">{error_to_string(err)}</p>
              <% end %>
            <% end %>
          </div>

          <.input field={@form[:bio]} type="textarea" label="Bio" rows="5" />
          <.input field={@form[:statement]} type="textarea" label="Statement" rows="3" />

          <%= if @participant.id do %>
            <div class="space-y-2">
              <label class="block text-sm font-semibold text-gray-900">
                Linked Artworks
              </label>

              <%= if @linked_artworks == [] do %>
                <p class="text-sm text-gray-500 mb-2">
                  No artworks linked yet
                </p>
              <% else %>
                <div class="space-y-2 mb-2">
                  <div
                    :for={rel <- @linked_artworks}
                    class="flex items-center justify-between bg-gray-50 p-3 rounded-lg"
                  >
                    <div class="min-w-0">
                      <div class="text-sm font-medium text-gray-900 truncate">
                        <.link
                          navigate={"/admin/artworks/#{rel.subject_id}"}
                          class="hover:text-blue-600"
                        >
                          {field(rel.subject, "title")}
                        </.link>
                      </div>
                      <div class="text-xs text-gray-500">
                        <%= if field(rel.subject, "type") do %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                            {field(rel.subject, "type")}
                          </span>
                        <% end %>
                        <%= if field(rel.subject, "date") do %>
                          <span class="ml-1">{field(rel.subject, "date")}</span>
                        <% end %>
                        <%= if rel.fields["role"] do %>
                          <span class="ml-1 inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            {rel.fields["role"]}
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="unlink_artwork"
                      phx-value-artwork-id={rel.subject_id}
                      phx-target={@myself}
                      class="text-red-600 hover:text-red-700 flex-shrink-0 ml-2"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              <% end %>

              <div phx-change="search_artwork_to_link" phx-target={@myself}>
                <input
                  type="text"
                  name="search"
                  value={@artwork_search}
                  placeholder="Search artworks by title to link..."
                  phx-debounce="300"
                  class="w-full rounded-lg border-gray-300 bg-white text-gray-900 px-3 py-2"
                />
              </div>

              <%= if @artwork_results != [] do %>
                <div class="border border-gray-200 rounded-lg max-h-48 overflow-y-auto divide-y divide-gray-100">
                  <button
                    :for={{id, identity, date} <- @artwork_results}
                    type="button"
                    phx-click="link_artwork"
                    phx-value-artwork-id={id}
                    phx-target={@myself}
                    class="w-full text-left px-3 py-2 hover:bg-blue-50 transition-colors"
                  >
                    <span class="text-sm text-gray-900">{identity}</span>
                    <%= if date do %>
                      <span class="text-xs text-gray-500 ml-2">{date}</span>
                    <% end %>
                    <span class="text-xs text-gray-400 ml-2">#{id}</span>
                  </button>
                </div>
              <% else %>
                <%= if @artwork_search != "" do %>
                  <p class="text-xs text-gray-500">No artworks found</p>
                <% end %>
              <% end %>
            </div>
          <% else %>
            <p class="text-xs text-gray-500">
              Save the participant first to link artworks.
            </p>
          <% end %>
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Participant
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{participant: participant} = assigns, socket) do
    headshot_media = get_headshot_media(participant)
    form_attrs = participant_form_attrs(participant)

    linked_artworks =
      if participant.id do
        Content.list_participant_linked_artworks(participant)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:social_platforms, @social_platforms)
     |> assign(:headshot_media, headshot_media)
     |> assign(:social_media_entries, form_attrs[:social_media] || [])
     |> assign(:linked_artworks, linked_artworks)
     |> assign(:artwork_search, "")
     |> assign(:artwork_results, [])
     |> assign_new(:form, fn ->
       changeset = ParticipantForm.changeset(%ParticipantForm{}, form_attrs)
       to_form(changeset, as: :participant)
     end)
     |> allow_upload(:headshot,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_event("validate", params, socket) do
    participant_params = extract_participant_params(params)
    social_media_entries = extract_social_media_from_params(participant_params)

    changeset =
      socket.assigns.form.source.data
      |> ParticipantForm.changeset(participant_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, as: :participant))
     |> assign(:social_media_entries, social_media_entries)}
  end

  def handle_event("add_social_media", _params, socket) do
    new_entries = socket.assigns.social_media_entries ++ [%{"platform" => "", "handle" => ""}]

    {:noreply, assign(socket, :social_media_entries, new_entries)}
  end

  def handle_event("remove_social_media", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    new_entries = List.delete_at(socket.assigns.social_media_entries, index)

    {:noreply, assign(socket, :social_media_entries, new_entries)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :headshot, ref)}
  end

  def handle_event("remove_headshot", _params, socket) do
    participant = socket.assigns.participant

    if participant.id && socket.assigns.headshot_media do
      Content.detach_media_from_entity(participant, socket.assigns.headshot_media)
    end

    {:noreply, assign(socket, headshot_media: nil)}
  end

  def handle_event("search_artwork_to_link", %{"search" => search}, socket) do
    participant = socket.assigns.participant

    results =
      if participant.id && String.trim(search) != "" do
        linked_ids = Enum.map(socket.assigns.linked_artworks, & &1.subject_id)
        pattern = "%#{String.downcase(search)}%"

        import Ecto.Query

        MykonosBiennale.Repo.all(
          from e in MykonosBiennale.Content.Entity,
            where:
              e.type == "artwork" and
                e.id not in ^linked_ids and
                (ilike(fragment("lower(?)", e.identity), ^pattern) or
                   ilike(fragment("lower(?->>'title')", e.fields), ^pattern)),
            limit: 10,
            select: {e.id, e.identity, fragment("?->>'date'", e.fields)}
        )
      else
        []
      end

    {:noreply,
     socket
     |> assign(:artwork_search, search)
     |> assign(:artwork_results, results)}
  end

  def handle_event("link_artwork", %{"artwork-id" => artwork_id}, socket) do
    participant = socket.assigns.participant

    if participant.id do
      artwork = Content.get_artwork!(artwork_id)

      case Content.attach_participant_to_artwork(artwork, participant, "creator") do
        {:ok, _} ->
          linked_artworks = Content.list_participant_linked_artworks(participant)

          {:noreply,
           socket
           |> assign(:linked_artworks, linked_artworks)
           |> assign(:artwork_search, "")
           |> assign(:artwork_results, [])
           |> put_flash(:info, "Artwork linked successfully")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not link artwork: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Save the participant first before linking artworks")}
    end
  end

  def handle_event("unlink_artwork", %{"artwork-id" => artwork_id}, socket) do
    participant = socket.assigns.participant
    artwork_id = String.to_integer(artwork_id)

    {:ok, _} = Content.detach_artwork_from_participant(participant, artwork_id)

    linked_artworks = Content.list_participant_linked_artworks(participant)

    {:noreply,
     socket
     |> assign(:linked_artworks, linked_artworks)
     |> put_flash(:info, "Artwork unlinked successfully")}
  end

  def handle_event("save", params, socket) do
    participant_params = extract_participant_params(params)
    save_participant(socket, socket.assigns.action, participant_params)
  end

  defp save_participant(socket, :edit, participant_params) do
    changeset = ParticipantForm.changeset(socket.assigns.form.source.data, participant_params)

    if changeset.valid? do
      attrs = participant_attrs_from_form(changeset, participant_params)

      case Content.update_participant(socket.assigns.participant, attrs) do
        {:ok, participant} ->
          maybe_upload_headshot(socket, participant)
          notify_parent({:saved, participant})

          {:noreply,
           socket
           |> put_flash(:info, "Participant updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update participant")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :participant)
           )}
      end
    else
      {:noreply,
       assign(socket, form: to_form(%{changeset | action: :validate}, as: :participant))}
    end
  end

  defp save_participant(socket, :new, participant_params) do
    changeset = ParticipantForm.changeset(socket.assigns.form.source.data, participant_params)

    if changeset.valid? do
      attrs = participant_attrs_from_form(changeset, participant_params)

      case Content.create_participant(attrs) do
        {:ok, participant} ->
          maybe_upload_headshot(socket, participant)
          notify_parent({:saved, participant})

          {:noreply,
           socket
           |> put_flash(:info, "Participant created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create participant")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :participant)
           )}
      end
    else
      {:noreply,
       assign(socket, form: to_form(%{changeset | action: :validate}, as: :participant))}
    end
  end

  defp maybe_upload_headshot(socket, participant) do
    uploaded_files =
      consume_uploaded_entries(socket, :headshot, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = MykonosBiennale.Uploads.uploads_path(filename)
        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.cp!(path, dest)
        {:ok, %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
      end)

    case uploaded_files do
      [%{path: path, mime_type: mime_type, original_name: original_name}] ->
        {:ok, media} =
          Content.create_media(%{
            caption: "Headshot - #{field(participant, "name")}",
            source_type: "upload",
            source_path: path,
            mime_type: mime_type,
            original_name: original_name
          })

        Content.attach_media_to_entity(participant, media, metadata: %{"role" => "headshot"})

      [] ->
        :ok
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp extract_participant_params(%{"participant" => p}) when is_map(p), do: p
  defp extract_participant_params(_), do: %{}

  defp extract_social_media_from_params(params) do
    case Map.get(params, "social_media") do
      sm when is_map(sm) ->
        sm
        |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
        |> Enum.map(fn {_k, v} -> v end)

      _ ->
        []
    end
  end

  defp participant_form_attrs(%Content.Entity{fields: fields}) when is_map(fields) do
    social_media =
      case Map.get(fields, "social_media") do
        sm when is_list(sm) ->
          Enum.map(sm, fn
            %{"platform" => _, "handle" => _} = entry -> entry
            _ -> %{"platform" => "", "handle" => ""}
          end)

        _ ->
          []
      end

    %{
      first_name: Map.get(fields, "first_name"),
      last_name: Map.get(fields, "last_name"),
      name: Map.get(fields, "name"),
      country: Map.get(fields, "country"),
      email: Map.get(fields, "email"),
      phone: Map.get(fields, "phone"),
      website: Map.get(fields, "website"),
      social_media: social_media,
      bio: Map.get(fields, "bio"),
      statement: Map.get(fields, "statement"),
      visible: true
    }
  end

  defp participant_form_attrs(%Content.Entity{}), do: %{visible: true, social_media: []}

  defp participant_attrs_from_form(%Changeset{} = changeset, params) do
    form = Changeset.apply_changes(changeset)
    social_media = extract_social_media_from_params(params)

    social_media =
      Enum.reject(social_media, fn sm -> sm["platform"] == "" and sm["handle"] == "" end)

    %{
      first_name: form.first_name,
      last_name: form.last_name,
      name: form.name,
      country: form.country,
      email: form.email,
      phone: form.phone,
      website: form.website,
      social_media: social_media,
      bio: form.bio,
      statement: form.statement
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp get_headshot_media(%Content.Entity{id: nil}), do: nil

  defp get_headshot_media(%Content.Entity{} = entity) do
    links = Content.list_entity_media_links_for_entity(entity)

    Enum.find_value(links, fn link ->
      if link.metadata && link.metadata["role"] == "headshot", do: link.media
    end)
  end

  defp headshot_url(%Media{source_type: "upload"} = media),
    do: MykonosBiennale.Uploads.media_url(media, size: "admin")

  defp headshot_url(%Media{source_type: "url", source_url: url}) when is_binary(url), do: url
  defp headshot_url(_), do: ""

  defp field(%Content.Entity{fields: fields}, key) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key))
  end

  defp field(_, _), do: nil

  defp country_options do
    [
      "Afghanistan",
      "Albania",
      "Algeria",
      "Andorra",
      "Angola",
      "Antigua and Barbuda",
      "Argentina",
      "Armenia",
      "Australia",
      "Austria",
      "Azerbaijan",
      "Bahamas",
      "Bahrain",
      "Bangladesh",
      "Barbados",
      "Belarus",
      "Belgium",
      "Belize",
      "Benin",
      "Bhutan",
      "Bolivia",
      "Bosnia and Herzegovina",
      "Botswana",
      "Brazil",
      "Brunei",
      "Bulgaria",
      "Burkina Faso",
      "Burundi",
      "Cabo Verde",
      "Cambodia",
      "Cameroon",
      "Canada",
      "Central African Republic",
      "Chad",
      "Chile",
      "China",
      "Colombia",
      "Comoros",
      "Congo",
      "Costa Rica",
      "Croatia",
      "Cuba",
      "Cyprus",
      "Czech Republic",
      "Denmark",
      "Djibouti",
      "Dominica",
      "Dominican Republic",
      "Ecuador",
      "Egypt",
      "El Salvador",
      "Equatorial Guinea",
      "Eritrea",
      "Estonia",
      "Eswatini",
      "Ethiopia",
      "Fiji",
      "Finland",
      "France",
      "Gabon",
      "Gambia",
      "Georgia",
      "Germany",
      "Ghana",
      "Greece",
      "Grenada",
      "Guatemala",
      "Guinea",
      "Guinea-Bissau",
      "Guyana",
      "Haiti",
      "Honduras",
      "Hungary",
      "Iceland",
      "India",
      "Indonesia",
      "Iran",
      "Iraq",
      "Ireland",
      "Israel",
      "Italy",
      "Jamaica",
      "Japan",
      "Jordan",
      "Kazakhstan",
      "Kenya",
      "Kiribati",
      "Kosovo",
      "Kuwait",
      "Kyrgyzstan",
      "Laos",
      "Latvia",
      "Lebanon",
      "Lesotho",
      "Liberia",
      "Libya",
      "Liechtenstein",
      "Lithuania",
      "Luxembourg",
      "Madagascar",
      "Malawi",
      "Malaysia",
      "Maldives",
      "Mali",
      "Malta",
      "Marshall Islands",
      "Mauritania",
      "Mauritius",
      "Mexico",
      "Micronesia",
      "Moldova",
      "Monaco",
      "Mongolia",
      "Montenegro",
      "Morocco",
      "Mozambique",
      "Myanmar",
      "Namibia",
      "Nauru",
      "Nepal",
      "Netherlands",
      "New Zealand",
      "Nicaragua",
      "Niger",
      "Nigeria",
      "North Korea",
      "North Macedonia",
      "Norway",
      "Oman",
      "Pakistan",
      "Palau",
      "Palestine",
      "Panama",
      "Papua New Guinea",
      "Paraguay",
      "Peru",
      "Philippines",
      "Poland",
      "Portugal",
      "Qatar",
      "Romania",
      "Russia",
      "Rwanda",
      "Saint Kitts and Nevis",
      "Saint Lucia",
      "Saint Vincent and the Grenadines",
      "Samoa",
      "San Marino",
      "Sao Tome and Principe",
      "Saudi Arabia",
      "Senegal",
      "Serbia",
      "Seychelles",
      "Sierra Leone",
      "Singapore",
      "Slovakia",
      "Slovenia",
      "Solomon Islands",
      "Somalia",
      "South Africa",
      "South Korea",
      "South Sudan",
      "Spain",
      "Sri Lanka",
      "Sudan",
      "Suriname",
      "Sweden",
      "Switzerland",
      "Syria",
      "Taiwan",
      "Tajikistan",
      "Tanzania",
      "Thailand",
      "Togo",
      "Tonga",
      "Trinidad and Tobago",
      "Tunisia",
      "Turkey",
      "Turkmenistan",
      "Tuvalu",
      "Uganda",
      "Ukraine",
      "United Arab Emirates",
      "United Kingdom",
      "United States",
      "Uruguay",
      "Uzbekistan",
      "Vanuatu",
      "Vatican City",
      "Venezuela",
      "Vietnam",
      "Yemen",
      "Zambia",
      "Zimbabwe"
    ]
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
end
