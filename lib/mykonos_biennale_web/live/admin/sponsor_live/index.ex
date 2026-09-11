defmodule MykonosBiennaleWeb.Admin.SponsorLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, EntityMedia, Media}

  @impl true
  def mount(_params, _session, socket) do
    biennales = Content.list_biennales()

    {:ok,
     socket
     |> assign(:page_title, "Sponsors")
     |> assign(:biennales, biennales)
     |> allow_upload(:sponsor_logo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> load_sponsors()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"name" => name}) do
    sponsor =
      Enum.find(socket.assigns.sponsors, &(URI.decode_www_form(name) == &1.name))

    socket
    |> assign(:page_title, "Edit Sponsor")
    |> assign(:sponsor, sponsor)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add Sponsor")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sponsors")
    |> assign(:sponsor, nil)
  end

  # -- Loading --

  defp load_sponsors(socket) do
    links =
      Repo.all(
        from em in EntityMedia,
          where: fragment("? ->> 'role'", em.metadata) == "sponsor",
          preload: [:media, :entity]
      )

    biennale_year = fn entity ->
      entity && entity.fields && entity.fields["year"]
    end

    sponsors =
      links
      |> Enum.group_by(fn link ->
        link.metadata["name"] || link.media.caption || ""
      end)
      |> Enum.map(fn {name, group_links} ->
        %{
          name: name,
          media: hd(group_links).media,
          url: hd(group_links).metadata["url"] || "",
          years:
            group_links
            |> Enum.map(&biennale_year.(&1.entity))
            |> Enum.reject(&is_nil/1)
            |> Enum.sort(:desc),
          links: group_links
        }
      end)
      |> Enum.sort_by(& &1.name)

    assign(socket, :sponsors, sponsors)
  end

  # -- Events --

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :sponsor_logo, ref)}
  end

  def handle_event("add_sponsor", params, socket) do
    name = String.trim(params["sponsor_name"] || "")
    url = String.trim(params["sponsor_url"] || "")
    biennale_ids = biennale_ids_from_params(params)
    uploaded_files = consume_sponsor_uploads(socket)

    cond do
      name == "" ->
        {:noreply, put_flash(socket, :error, "Enter a sponsor name")}

      uploaded_files == [] ->
        {:noreply, put_flash(socket, :error, "Upload a sponsor logo")}

      biennale_ids == [] ->
        {:noreply, put_flash(socket, :error, "Select at least one biennale")}

      true ->
        [%{media: media}] = uploaded_files

        metadata =
          %{"role" => "sponsor", "name" => name}
          |> then(fn m -> if url != "", do: Map.put(m, "url", url), else: m end)

        results =
          for biennale <- socket.assigns.biennales, biennale.id in biennale_ids do
            attach(biennale, media, metadata)
          end

        if Enum.all?(results, &(&1 == :ok)) do
          {:noreply,
           socket
           |> load_sponsors()
           |> put_flash(:info, "Sponsor added to #{length(biennale_ids)} biennale(s)")
           |> push_patch(to: "/admin/sponsors")}
        else
          {:noreply, put_flash(socket, :error, "Could not add sponsor")}
        end
    end
  end

  def handle_event("update_sponsor", params, socket) do
    name = String.trim(params["sponsor_name"] || "")
    url = String.trim(params["sponsor_url"] || "")

    if name == "" do
      {:noreply, put_flash(socket, :error, "Enter a sponsor name")}
    else
      sponsor = socket.assigns.sponsor
      uploaded_files = consume_sponsor_uploads(socket)

      new_media =
        case uploaded_files do
          [%{media: m} | _] -> m
          [] -> nil
        end

      if sponsor do
        metadata =
          %{"role" => "sponsor", "name" => name}
          |> then(fn m -> if url != "", do: Map.put(m, "url", url), else: m end)

        # Update (or re-attach with new logo) the existing memberships
        Enum.each(sponsor.links, fn link ->
          if new_media do
            Content.detach_media_from_entity(link.entity, link.media)
            Content.attach_media_to_entity(link.entity, new_media, metadata: metadata)
          else
            Content.update_entity_media_link(link.entity, link.media, metadata)
          end
        end)

        # Attach any newly selected biennales
        existing_entity_ids = MapSet.new(sponsor.links, & &1.entity_id)
        attach_media = new_media || sponsor.media

        added =
          socket.assigns.biennales
          |> Enum.filter(fn b ->
            b.id in biennale_ids_from_params(params) and
              not MapSet.member?(existing_entity_ids, b.id)
          end)
          |> Enum.map(fn biennale ->
            Content.attach_media_to_entity(biennale, attach_media, metadata: metadata)
          end)
          |> Enum.count(&match?({:ok, _}, &1))

        {:noreply,
         socket
         |> load_sponsors()
         |> put_flash(
           :info,
           "Sponsor updated#{if added > 0, do: " — added to #{added} more biennale(s)"}"
         )
         |> push_patch(to: "/admin/sponsors")}
      else
        {:noreply, put_flash(socket, :error, "Sponsor not found")}
      end
    end
  end

  def handle_event("remove_year", %{"entity-id" => entity_id, "media-id" => media_id}, socket) do
    entity = Repo.get(Entity, String.to_integer(entity_id))
    media = Repo.get(Media, String.to_integer(media_id))

    if entity && media do
      Content.detach_media_from_entity(entity, media)
    end

    {:noreply,
     socket
     |> load_sponsors()
     |> put_flash(:info, "Sponsorship removed")}
  end

  def handle_event("delete", %{"name" => name}, socket) do
    sponsor = Enum.find(socket.assigns.sponsors, &(&1.name == name))

    if sponsor do
      Enum.each(sponsor.links, fn link ->
        Content.detach_media_from_entity(link.entity, link.media)
      end)
    end

    {:noreply,
     socket
     |> load_sponsors()
     |> put_flash(:info, "Sponsor deleted")}
  end

  # -- Helpers --

  defp attach(biennale, media, metadata) do
    case Content.attach_media_to_entity(biennale, media, metadata: metadata) do
      {:ok, :attached} -> :ok
      {:error, _} -> :error
    end
  end

  defp consume_sponsor_uploads(socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :sponsor_logo, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = MykonosBiennale.Uploads.uploads_path(filename)
        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.cp!(path, dest)
        {:ok, %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
      end)

    for %{path: path, mime_type: mime_type, original_name: original_name} <- uploaded_files do
      caption = Path.basename(original_name, Path.extname(original_name))

      {:ok, media} =
        Content.create_media(%{
          caption: caption,
          source_type: "upload",
          source_path: path,
          mime_type: mime_type,
          original_name: original_name
        })

      %{media: media}
    end
  end

  defp biennale_ids_from_params(params) do
    params
    |> Enum.filter(fn {k, v} -> String.starts_with?(k, "biennale_") and v == "true" end)
    |> Enum.map(fn {k, _} -> String.replace_prefix(k, "biennale_", "") |> String.to_integer() end)
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
