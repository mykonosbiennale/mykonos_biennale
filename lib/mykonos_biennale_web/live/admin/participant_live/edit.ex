defmodule MykonosBiennaleWeb.Admin.ParticipantLive.Edit do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Repo
  alias Ecto.Changeset

  alias MykonosBiennaleWeb.Admin.ParticipantLive.FormComponent
  alias MykonosBiennaleWeb.Admin.ParticipantLive.FormComponent.ParticipantForm

  @social_platforms FormComponent.social_platforms()

  @impl true
  def render(assigns), do: MykonosBiennaleWeb.Admin.ParticipantLive.EditHTML.render(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:social_platforms, @social_platforms)
     |> allow_upload(:headshot,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    participant = Content.get_participant!(id)
    headshot_media = get_headshot_media(participant)
    form_attrs = participant_form_attrs(participant)
    linked_artworks = Content.list_participant_linked_artworks(participant)
    relationships = list_relationships(participant)

    changeset = ParticipantForm.changeset(%ParticipantForm{}, form_attrs)

    {:noreply,
     socket
     |> assign(:page_title, "Edit Participant")
     |> assign(:participant, participant)
     |> assign(:headshot_media, headshot_media)
     |> assign(:social_media_entries, form_attrs[:social_media] || [])
     |> assign(:linked_artworks, linked_artworks)
     |> assign(:relationships, relationships)
     |> assign(:all_relationship_types, Content.list_relationship_types())
     |> assign(:show_add_relationship, false)
     |> assign(:new_rel_type, nil)
     |> assign(:new_rel_direction, "object")
     |> assign(:new_rel_search, "")
     |> assign(:new_rel_results, [])
     |> assign(:new_rel_selected_entity, nil)
     |> assign(:new_rel_fields, "")
     |> assign(:artwork_search, "")
     |> assign(:artwork_results, [])
     |> assign(:form, to_form(changeset, as: :participant))}
  end

  # ── Form validation / save ──

  @impl true
  def handle_event("search", _params, socket) do
    {:noreply, push_navigate(socket, to: "/admin/participants")}
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

  def handle_event("save", params, socket) do
    participant_params = extract_participant_params(params)
    changeset = ParticipantForm.changeset(socket.assigns.form.source.data, participant_params)

    if changeset.valid? do
      attrs = participant_attrs_from_form(changeset, participant_params)

      case Content.update_participant(socket.assigns.participant, attrs) do
        {:ok, participant} ->
          maybe_upload_headshot(socket, participant)

          {:noreply,
           socket
           |> put_flash(:info, "Participant updated successfully")
           |> push_navigate(to: "/admin/participants/#{participant.id}")}

        {:error, %Ecto.Changeset{} = cs} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update participant")
           |> assign(
             :form,
             to_form(Changeset.add_error(cs, :base, "Save failed"), as: :participant)
           )}
      end
    else
      {:noreply,
       assign(socket, form: to_form(%{changeset | action: :validate}, as: :participant))}
    end
  end

  # ── Social media ──

  def handle_event("add_social_media", _params, socket) do
    {:noreply,
     assign(
       socket,
       :social_media_entries,
       socket.assigns.social_media_entries ++ [%{"platform" => "", "handle" => ""}]
     )}
  end

  def handle_event("remove_social_media", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    {:noreply,
     assign(
       socket,
       :social_media_entries,
       List.delete_at(socket.assigns.social_media_entries, index)
     )}
  end

  # ── Headshot ──

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

  # ── Linked artworks ──

  def handle_event("search_artwork_to_link", %{"search" => search}, socket) do
    participant = socket.assigns.participant

    results =
      if participant.id && String.trim(search) != "" do
        linked_ids = Enum.map(socket.assigns.linked_artworks, & &1.subject_id)
        pattern = "%#{String.downcase(search)}%"

        import Ecto.Query

        Repo.all(
          from e in Entity,
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

    {:noreply, socket |> assign(:artwork_search, search) |> assign(:artwork_results, results)}
  end

  def handle_event("link_artwork", %{"artwork-id" => artwork_id}, socket) do
    participant = socket.assigns.participant
    artwork = Content.get_artwork!(artwork_id)

    case Content.attach_participant_to_artwork(artwork, participant, "creator") do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:linked_artworks, Content.list_participant_linked_artworks(participant))
         |> assign(:artwork_search, "")
         |> assign(:artwork_results, [])
         |> put_flash(:info, "Artwork linked successfully")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not link artwork: #{inspect(reason)}")}
    end
  end

  def handle_event("unlink_artwork", %{"artwork-id" => artwork_id}, socket) do
    participant = socket.assigns.participant
    artwork_id = String.to_integer(artwork_id)

    {:ok, _} = Content.detach_artwork_from_participant(participant, artwork_id)

    {:noreply,
     socket
     |> assign(:linked_artworks, Content.list_participant_linked_artworks(participant))
     |> put_flash(:info, "Artwork unlinked successfully")}
  end

  # ── Relationships ──

  def handle_event("update_rel_type", %{"_target" => [target_name]} = params, socket) do
    # target_name is like "rel_type_2279"
    "rel_type_" <> rel_id = target_name
    type_id_str = params[target_name]
    rel = Repo.get(MykonosBiennale.Content.Relationship, rel_id)

    if rel do
      type_id = String.to_integer(type_id_str)

      rel
      |> Ecto.Changeset.change(relationship_type_id: type_id)
      |> Repo.update()

      {:noreply,
       socket
       |> assign(:relationships, list_relationships(socket.assigns.participant))
       |> put_flash(:info, "Relationship type updated")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_rel_role", %{"rel-id" => rel_id, "value" => role}, socket) do
    rel = Repo.get(MykonosBiennale.Content.Relationship, rel_id)

    if rel do
      fields = if String.trim(role) == "", do: %{}, else: %{"roles" => String.trim(role)}

      rel
      |> Ecto.Changeset.change(fields: fields)
      |> Repo.update()

      {:noreply,
       socket
       |> assign(:relationships, list_relationships(socket.assigns.participant))
       |> put_flash(:info, "Role updated")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_relationship", %{"rel-id" => rel_id}, socket) do
    rel = Repo.get(MykonosBiennale.Content.Relationship, rel_id)

    if rel do
      {:ok, _} = Content.delete_relationship(rel)

      {:noreply,
       socket
       |> assign(:relationships, list_relationships(socket.assigns.participant))
       |> put_flash(:info, "Relationship deleted")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_add_relationship", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_relationship, !socket.assigns.show_add_relationship)
     |> assign(:new_rel_search, "")
     |> assign(:new_rel_results, [])
     |> assign(:new_rel_selected_entity, nil)
     |> assign(:new_rel_fields, "")}
  end

  def handle_event("new_rel_type_changed", %{"new_rel_type" => type_id}, socket) do
    {:noreply, assign(socket, :new_rel_type, type_id)}
  end

  def handle_event("new_rel_direction_changed", %{"new_rel_direction" => dir}, socket) do
    {:noreply, assign(socket, :new_rel_direction, dir)}
  end

  def handle_event("new_rel_fields_changed", %{"new_rel_fields" => fields}, socket) do
    {:noreply, assign(socket, :new_rel_fields, fields)}
  end

  def handle_event("new_rel_clear_entity", _params, socket) do
    {:noreply, assign(socket, :new_rel_selected_entity, nil)}
  end

  def handle_event("new_rel_search_changed", %{"new_rel_search" => search}, socket) do
    results = search_entities(search)
    {:noreply, socket |> assign(:new_rel_search, search) |> assign(:new_rel_results, results)}
  end

  def handle_event("new_rel_select_entity", %{"entity-id" => entity_id}, socket) do
    entity = Repo.get(Entity, entity_id)

    {:noreply,
     socket
     |> assign(:new_rel_selected_entity, entity)
     |> assign(:new_rel_search, "")
     |> assign(:new_rel_results, [])}
  end

  def handle_event("create_relationship", _params, socket) do
    participant = socket.assigns.participant
    type_id = socket.assigns[:new_rel_type]
    direction = socket.assigns[:new_rel_direction] || "object"
    selected = socket.assigns[:new_rel_selected_entity]
    fields_str = socket.assigns[:new_rel_fields]

    cond do
      is_nil(type_id) or type_id == "" ->
        {:noreply, put_flash(socket, :error, "Select a relationship type")}

      is_nil(selected) ->
        {:noreply, put_flash(socket, :error, "Select an entity")}

      true ->
        {subject_id, object_id} =
          case direction do
            "subject" -> {participant.id, selected.id}
            _ -> {selected.id, participant.id}
          end

        fields =
          case fields_str do
            nil -> %{}
            "" -> %{}
            str -> %{"roles" => String.trim(str)}
          end

        rt = Repo.get!(MykonosBiennale.Content.RelationshipType, String.to_integer(type_id))

        rel_attrs = %{
          relationship_type_id: rt.id,
          subject_id: subject_id,
          object_id: object_id,
          fields: fields
        }

        case MykonosBiennale.Content.Relationship.changeset(
               %MykonosBiennale.Content.Relationship{},
               rel_attrs
             )
             |> Repo.insert() do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:relationships, list_relationships(participant))
             |> assign(:show_add_relationship, false)
             |> assign(:new_rel_type, nil)
             |> assign(:new_rel_selected_entity, nil)
             |> assign(:new_rel_search, "")
             |> assign(:new_rel_results, [])
             |> assign(:new_rel_fields, "")
             |> put_flash(:info, "Relationship created")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create relationship")}
        end
    end
  end

  # ── Helpers ──

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

  defp participant_form_attrs(%Entity{fields: fields}) when is_map(fields) do
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

  defp participant_form_attrs(%Entity{}), do: %{visible: true, social_media: []}

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

  defp get_headshot_media(%Entity{id: nil}), do: nil

  defp get_headshot_media(%Entity{} = entity) do
    links = Content.list_entity_media_links_for_entity(entity)

    Enum.find_value(links, fn link ->
      if link.metadata && link.metadata["role"] == "headshot", do: link.media
    end)
  end

  defp field(%Entity{fields: fields}, key) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key))
  end

  defp field(_, _), do: nil

  defp list_relationships(participant) do
    import Ecto.Query

    Repo.all(
      from r in MykonosBiennale.Content.Relationship,
        where: r.subject_id == ^participant.id or r.object_id == ^participant.id,
        preload: [:subject, :object, :relationship_type]
    )
    |> Enum.sort_by(fn r -> {r.relationship_type.slug, r.subject_id != participant.id} end)
  end

  defp search_entities(search) when is_binary(search) and byte_size(search) > 0 do
    import Ecto.Query

    Repo.all(
      from e in Entity,
        where: e.visible == true and ilike(e.identity, ^"%#{search}%"),
        limit: 20
    )
  end

  defp search_entities(_), do: []
end
