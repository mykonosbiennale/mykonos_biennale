defmodule MykonosBiennaleWeb.Admin.TeamLive.Member do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Media, Relationship, RelationshipType}

  @team_roles [
    curator: "Curator",
    producer: "Producer",
    director: "Director",
    coordinator: "Coordinator",
    designer: "Designer",
    technical: "Technical",
    volunteer: "Volunteer"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:team_roles, @team_roles)
     |> assign(:editing, nil)
     |> allow_upload(:image,
       accept: ~w(.jpg .jpeg .gif .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    participant = Repo.get!(Entity, id)

    {:noreply,
     socket
     |> assign(:participant, participant)
     |> load_memberships()}
  end

  # -- Events --

  @impl true
  def handle_event("edit_membership", %{"rel-id" => rel_id}, socket) do
    rel_id = String.to_integer(rel_id)

    editing =
      Enum.find(socket.assigns.memberships, &(&1.rel_id == rel_id))

    {:noreply, assign(socket, :editing, editing)}
  end

  def handle_event("close_edit", _params, socket) do
    {:noreply, assign(socket, :editing, nil)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("validate_membership", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_membership", %{"rel_id" => rel_id, "role" => role}, socket) do
    rel_id = String.to_integer(rel_id)

    uploaded =
      consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = MykonosBiennale.Uploads.uploads_path(filename)
        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.cp!(path, dest)
        {:ok, %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
      end)

    image_media_id =
      case uploaded do
        [%{path: path, mime_type: mime_type, original_name: original_name}] ->
          {:ok, media} =
            Content.create_media(%{
              caption: "#{socket.assigns.participant.identity} team image",
              source_type: "upload",
              source_path: path,
              mime_type: mime_type,
              original_name: original_name
            })

          media.id

        [] ->
          nil
      end

    update_rel_fields(rel_id, fn fields ->
      fields
      |> Map.put("role", role)
      |> then(fn f ->
        if image_media_id, do: Map.put(f, "image_media_id", image_media_id), else: f
      end)
    end)

    {:noreply,
     socket
     |> assign(:editing, nil)
     |> load_memberships()
     |> put_flash(:info, "Membership updated")}
  end

  def handle_event("clear_image", %{"rel-id" => rel_id}, socket) do
    update_rel_fields(rel_id, &Map.delete(&1, "image_media_id"))

    {:noreply,
     socket
     |> assign(:editing, nil)
     |> load_memberships()
     |> put_flash(:info, "Reverted to headshot")}
  end

  def handle_event("remove_membership", %{"rel-id" => rel_id}, socket) do
    rel = Repo.get(Relationship, rel_id)
    if rel, do: {:ok, _} = Content.delete_relationship(rel)

    {:noreply,
     socket
     |> assign(:editing, nil)
     |> load_memberships()
     |> put_flash(:info, "Membership removed")}
  end

  # -- Loading --

  defp load_memberships(socket) do
    participant = socket.assigns.participant
    bt_rt = Repo.get_by(RelationshipType, slug: "biennale_team")

    rels =
      if bt_rt do
        Repo.all(
          from r in Relationship,
            where: r.object_id == ^participant.id and r.relationship_type_id == ^bt_rt.id,
            preload: [:subject]
        )
        |> Enum.sort_by(fn r -> r.subject.fields["year"] || "0" end, :desc)
      else
        []
      end

    image_ids =
      rels
      |> Enum.map(&(&1.fields && &1.fields["image_media_id"]))
      |> Enum.reject(&is_nil/1)

    images = load_media_map(image_ids)
    headshot = get_headshot(participant)

    memberships =
      Enum.map(rels, fn rel ->
        image_id = rel.fields && rel.fields["image_media_id"]

        %{
          rel_id: rel.id,
          biennale_id: rel.subject_id,
          year: rel.subject && rel.subject.fields["year"],
          role: rel.fields && rel.fields["role"],
          role_label: role_label(rel.fields && rel.fields["role"]),
          image: Map.get(images, image_id),
          image_is_custom: not is_nil(image_id)
        }
      end)

    socket
    |> assign(:memberships, memberships)
    |> assign(:headshot, headshot)
  end

  defp role_label(role) when is_binary(role) do
    Enum.find_value(@team_roles, fn {value, label} ->
      if Atom.to_string(value) == role, do: label
    end) || role
  end

  defp role_label(role), do: role

  defp load_media_map([]), do: %{}

  defp load_media_map(ids) do
    Repo.all(from m in Media, where: m.id in ^ids)
    |> Map.new(&{&1.id, &1})
  end

  defp get_headshot(participant) do
    Content.list_entity_media_links_for_entity(participant)
    |> Enum.find_value(fn link ->
      if link.metadata && link.metadata["role"] == "headshot", do: link.media
    end)
  end

  defp update_rel_fields(rel_id, fun) do
    rel = Repo.get(Relationship, rel_id)

    if rel do
      fields = rel.fields || %{}
      rel |> Ecto.Changeset.change(fields: fun.(fields)) |> Repo.update()
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
