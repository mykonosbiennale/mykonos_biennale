defmodule MykonosBiennaleWeb.Admin.SponsorLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content
  alias MykonosBiennale.Sponsors

  @impl true
  def mount(_params, _session, socket) do
    biennales = Content.list_biennales()

    {:ok,
     socket
     |> assign(:page_title, "Sponsors")
     |> assign(:biennales, biennales)
     |> assign(:sponsor_form, %{})
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
    sponsor = Enum.find(socket.assigns.sponsors, &(URI.decode_www_form(name) == &1.name))

    # Biennales the sponsor already supports are pre-ticked and disabled: they
    # are removed from the list, not from this form. Saving only adds.
    ticked =
      if sponsor,
        do: Map.new(sponsor.biennales, &{"biennale_#{&1.id}", "true"}),
        else: %{}

    socket
    |> assign(:page_title, "Edit Sponsor")
    |> assign(:sponsor, sponsor)
    |> assign(:sponsor_form, ticked)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add Sponsor")
    |> assign(:sponsor_form, %{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sponsors")
    |> assign(:sponsor, nil)
  end

  defp load_sponsors(socket) do
    assign(socket, :sponsors, Sponsors.list_sponsors())
  end

  # -- Events --

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :sponsor_form, params)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :sponsor_logo, ref)}
  end

  def handle_event("add_sponsor", params, socket) do
    name = String.trim(params["sponsor_name"] || "")
    url = String.trim(params["sponsor_url"] || "")
    biennale_ids = biennale_ids_from_params(params)
    logo = consume_sponsor_logo(socket)

    cond do
      name == "" ->
        {:noreply, put_flash(socket, :error, "Enter a sponsor name")}

      biennale_ids == [] ->
        {:noreply, put_flash(socket, :error, "Select at least one biennale")}

      true ->
        case Sponsors.save(name, url, logo: logo) do
          {:ok, sponsor} ->
            Enum.each(biennale_ids, &Sponsors.link(sponsor.id, &1))

            {:noreply,
             socket
             |> load_sponsors()
             |> assign(:sponsor_form, %{})
             |> put_flash(:info, "Sponsor added to #{length(biennale_ids)} biennale(s)")
             |> push_patch(to: "/admin/sponsors")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  def handle_event("update_sponsor", params, socket) do
    name = String.trim(params["sponsor_name"] || "")
    url = String.trim(params["sponsor_url"] || "")

    cond do
      name == "" ->
        {:noreply, put_flash(socket, :error, "Enter a sponsor name")}

      socket.assigns[:sponsor] == nil ->
        {:noreply, put_flash(socket, :error, "Sponsor not found")}

      true ->
        sponsor = socket.assigns.sponsor
        biennale_ids = biennale_ids_from_params(params)
        previous_ids = Enum.map(sponsor.biennales, & &1.id)
        logo = consume_sponsor_logo(socket)

        case Sponsors.save(name, url, sponsor: sponsor.entity, logo: logo) do
          {:ok, entity} ->
            Enum.each(biennale_ids, &Sponsors.link(entity.id, &1))

            added = Enum.count(biennale_ids, &(&1 not in previous_ids))

            {:noreply,
             socket
             |> load_sponsors()
             |> put_flash(:info, updated_message(added))
             |> push_patch(to: "/admin/sponsors")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  def handle_event(
        "remove_year",
        %{"entity-id" => sponsor_id, "biennale-id" => biennale_id},
        socket
      ) do
    Sponsors.unlink(String.to_integer(sponsor_id), String.to_integer(biennale_id))

    {:noreply,
     socket
     |> load_sponsors()
     |> put_flash(:info, "Sponsorship removed")}
  end

  def handle_event("delete", %{"name" => name}, socket) do
    case Enum.find(socket.assigns.sponsors, &(&1.name == name)) do
      nil ->
        {:noreply, load_sponsors(socket)}

      sponsor ->
        Sponsors.delete(sponsor.entity)

        {:noreply,
         socket
         |> load_sponsors()
         |> put_flash(:info, "Sponsor deleted")}
    end
  end

  # -- Helpers --

  defp consume_sponsor_logo(socket) do
    consume_uploaded_entries(socket, :sponsor_logo, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      filename = "#{Ecto.UUID.generate()}#{ext}"
      dest = MykonosBiennale.Uploads.uploads_path(filename)
      MykonosBiennale.Uploads.ensure_uploads_dir()
      File.cp!(path, dest)
      {:ok, %{path: filename, mime_type: entry.client_type, original_name: entry.client_name}}
    end)
    |> case do
      [] ->
        nil

      [%{path: path, mime_type: mime_type, original_name: original_name} | _] ->
        {:ok, media} =
          Content.create_media(%{
            caption: Path.basename(original_name, Path.extname(original_name)),
            source_type: "upload",
            source_path: path,
            mime_type: mime_type,
            original_name: original_name
          })

        media
    end
  end

  defp updated_message(0), do: "Sponsor updated"
  defp updated_message(added), do: "Sponsor updated — added to #{added} more biennale(s)"

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp error_message(:name_taken), do: "Another sponsor already has that name"
  defp error_message(_), do: "Could not save the sponsor"

  defp biennale_ids_from_params(params) do
    params
    |> Enum.filter(fn {k, v} -> String.starts_with?(k, "biennale_") and v == "true" end)
    |> Enum.map(fn {k, _} ->
      k |> String.replace_prefix("biennale_", "") |> String.to_integer()
    end)
  end
end
