defmodule MykonosBiennaleWeb.Admin.ParticipantLive.EditHTML do
  use MykonosBiennaleWeb, :html

  alias MykonosBiennale.Content.Entity

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="mb-4 flex items-center justify-between">
        <h1 class="text-lg font-semibold text-gray-100">Edit Participant</h1>
        <.link
          navigate={"/admin/participants/#{@participant.id}"}
          class="text-sm text-gray-400 hover:text-gray-200"
        >
          ← Back to participant
        </.link>
      </div>

      <div
        data-theme="light"
        class="bg-white rounded-xl p-6 [&_.label]:text-gray-900 [&_h1]:text-gray-900"
      >
        <.form
          for={@form}
          id="participant-form"
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
                    class="text-red-500 hover:text-red-700 mt-2"
                  >
                    <.icon name="hero-x-mark" class="w-5 h-5" />
                  </button>
                </div>
              <% end %>

              <button
                type="button"
                phx-click="add_social_media"
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
                        class="text-red-600 hover:text-red-700 flex-shrink-0 ml-2"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>

                <div phx-change="search_artwork_to_link">
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
            <% end %>
          </div>

          <%= if @participant.id do %>
            <div class="mt-6">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-sm font-semibold text-gray-700">
                  Relationships ({length(@relationships)})
                </h3>
                <button
                  type="button"
                  phx-click="toggle_add_relationship"
                  class="px-3 py-1 bg-purple-600 hover:bg-purple-700 text-white text-xs font-medium rounded transition-colors"
                >
                  + Add
                </button>
              </div>

              <div class="overflow-x-auto border border-gray-200 rounded-lg">
                <table class="w-full text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase">
                        Type
                      </th>
                      <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase">
                        Dir
                      </th>
                      <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase">
                        Entity
                      </th>
                      <th class="px-3 py-2 text-left text-xs font-semibold text-gray-500 uppercase">
                        Role
                      </th>
                      <th class="px-3 py-2 text-right text-xs font-semibold text-gray-500 uppercase">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200">
                    <%= if @show_add_relationship do %>
                      <tr class="bg-purple-50">
                        <td class="px-3 py-2">
                          <select
                            name="new_rel_type"
                            phx-change="new_rel_type_changed"
                            class="w-full rounded border border-gray-300 text-xs text-gray-900 bg-white px-2 py-1"
                          >
                            <option value="">Select...</option>
                            <%= for rt <- @all_relationship_types do %>
                              <option value={rt.id} selected={to_string(rt.id) == @new_rel_type}>
                                {rt.slug}
                              </option>
                            <% end %>
                          </select>
                        </td>
                        <td class="px-3 py-2">
                          <select
                            name="new_rel_direction"
                            phx-change="new_rel_direction_changed"
                            class="w-full rounded border border-gray-300 text-xs text-gray-900 bg-white px-2 py-1"
                          >
                            <option value="object" selected={@new_rel_direction == "object"}>
                              ←
                            </option>
                            <option value="subject" selected={@new_rel_direction == "subject"}>
                              →
                            </option>
                          </select>
                        </td>
                        <td class="px-3 py-2 relative">
                          <%= if @new_rel_selected_entity do %>
                            <div class="flex items-center gap-2">
                              <span class="text-xs text-gray-700">
                                {@new_rel_selected_entity.identity}
                                <span class="text-gray-400">({@new_rel_selected_entity.type})</span>
                              </span>
                              <button
                                type="button"
                                phx-click="new_rel_clear_entity"
                                class="text-xs text-red-400 hover:text-red-600"
                              >
                                ✕
                              </button>
                            </div>
                          <% else %>
                            <input
                              type="text"
                              name="new_rel_search"
                              value={@new_rel_search}
                              phx-change="new_rel_search_changed"
                              phx-debounce="300"
                              placeholder="Search..."
                              class="w-full rounded border border-gray-300 text-xs text-gray-900 bg-white px-2 py-1"
                            />
                            <%= if @new_rel_results != [] do %>
                              <div class="absolute z-10 mt-1 max-h-48 overflow-y-auto border border-gray-200 rounded bg-white shadow-lg min-w-[300px]">
                                <%= for entity <- @new_rel_results do %>
                                  <button
                                    type="button"
                                    phx-click="new_rel_select_entity"
                                    phx-value-entity-id={entity.id}
                                    class="block w-full text-left px-3 py-1.5 text-xs text-gray-900 hover:bg-purple-50 border-b border-gray-100 last:border-0"
                                  >
                                    {entity.identity}
                                    <span class="text-gray-400 ml-1">({entity.type})</span>
                                  </button>
                                <% end %>
                              </div>
                            <% end %>
                          <% end %>
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="text"
                            name="new_rel_fields"
                            phx-change="new_rel_fields_changed"
                            value={@new_rel_fields}
                            placeholder="e.g. Director"
                            class="w-full rounded border border-gray-300 text-xs text-gray-900 bg-white px-2 py-1"
                          />
                        </td>
                        <td class="px-3 py-2 text-right whitespace-nowrap">
                          <button
                            type="button"
                            phx-click="create_relationship"
                            class="text-xs px-2 py-1 bg-purple-600 hover:bg-purple-700 text-white rounded"
                          >
                            Save
                          </button>
                          <button
                            type="button"
                            phx-click="toggle_add_relationship"
                            class="text-xs px-2 py-1 text-gray-500 hover:text-gray-700 ml-1"
                          >
                            Cancel
                          </button>
                        </td>
                      </tr>
                    <% end %>
                    <%= for rel <- @relationships do %>
                      <% is_subject = rel.subject_id == @participant.id
                      other = if is_subject, do: rel.object, else: rel.subject
                      direction = if is_subject, do: "→", else: "←"

                      other_name =
                        other &&
                          (other.fields["title"] || other.fields["name"] || other.identity ||
                             "##{other.id}")

                      other_type = other && other.type

                      role = rel.fields && rel.fields["roles"] %>
                      <tr class="hover:bg-gray-50">
                        <td class="px-3 py-2">
                          <select
                            name={"rel_type_#{rel.id}"}
                            phx-change="update_rel_type"
                            phx-value-rel-id={rel.id}
                            class="w-full rounded border border-gray-300 text-xs text-gray-900 bg-white px-2 py-1"
                          >
                            <%= for rt <- @all_relationship_types do %>
                              <option value={rt.id} selected={rt.id == rel.relationship_type_id}>
                                {rt.slug}
                              </option>
                            <% end %>
                          </select>
                        </td>
                        <td class="px-3 py-2 text-gray-400 font-mono">{direction}</td>
                        <td class="px-3 py-2 text-gray-700">
                          {other_name}<span class="text-gray-400 text-xs ml-1">({other_type})</span>
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="text"
                            name={"rel_role_#{rel.id}"}
                            value={role || ""}
                            placeholder="e.g. Director"
                            phx-blur="update_rel_role"
                            phx-value-rel-id={rel.id}
                            class="w-full rounded border border-gray-300 text-xs text-gray-900 bg-white px-2 py-1"
                          />
                        </td>
                        <td class="px-3 py-2 text-right">
                          <button
                            type="button"
                            phx-click="delete_relationship"
                            phx-value-rel-id={rel.id}
                            data-confirm="Delete this relationship?"
                            class="text-red-500 hover:text-red-700 text-xs"
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          <% end %>

          <div class="mt-6 flex items-center justify-end gap-x-6">
            <.link
              navigate={"/admin/participants/#{@participant.id}"}
              class="text-sm font-semibold text-gray-500 hover:text-gray-700"
            >
              Cancel
            </.link>
            <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
              Save Participant
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  # ── Private helpers (same as FormComponent) ──

  defp field(%Entity{fields: fields}, key) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key))
  end

  defp field(_, _), do: nil

  defp headshot_url(%MykonosBiennale.Content.Media{source_type: "upload"} = media),
    do: MykonosBiennale.Uploads.media_url(media, size: "admin")

  defp headshot_url(%MykonosBiennale.Content.Media{source_type: "url", source_url: url})
       when is_binary(url), do: url

  defp headshot_url(_), do: ""

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
end
