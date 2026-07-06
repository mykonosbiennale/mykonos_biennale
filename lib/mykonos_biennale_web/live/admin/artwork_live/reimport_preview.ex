defmodule MykonosBiennaleWeb.Admin.ArtworkLive.ReimportPreview do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.ReimportArtworks
  alias MykonosBiennale.Content.{Media, EntityMedia}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:groups, [])
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:total_pages, 1)
      |> assign(:total_groups, 0)
      |> assign(:total_records, 0)
      |> assign(:dup_groups, 0)
      |> assign(:media_matched, 0)
      |> assign(:media_unmatched, 0)
      |> assign(:imported, false)
      |> assign(:import_result, nil)
      |> assign(:loading, true)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns.groups == [] do
      groups = ReimportArtworks.build_groups()
      media_index = ReimportArtworks.build_media_index()

      {matched, unmatched} =
        Enum.reduce(groups, {0, 0}, fn group, {m, u} ->
          cnt =
            Enum.count(group.file_names, fn f -> Map.has_key?(media_index, f) end)

          {m + cnt, u + (length(group.file_names) - cnt)}
        end)

      total_records = Enum.sum(Enum.map(groups, & &1.count))
      dup_groups = Enum.count(groups, &(&1.count > 1))

      {:noreply,
       socket
       |> assign(:groups, groups)
       |> assign(:total_groups, length(groups))
       |> assign(:total_records, total_records)
       |> assign(:dup_groups, dup_groups)
       |> assign(:media_matched, matched)
       |> assign(:media_unmatched, unmatched)
       |> assign(:loading, false)
       |> assign_page(String.to_integer(params["page"] || "1"))}
    else
      {:noreply, assign_page(socket, String.to_integer(params["page"] || "1"))}
    end
  end

  defp assign_page(socket, page) do
    total_pages = max(1, ceil(socket.assigns.total_groups / socket.assigns.per_page))
    page = min(page, total_pages)
    offset = (page - 1) * socket.assigns.per_page
    page_groups = Enum.slice(socket.assigns.groups, offset, socket.assigns.per_page)

    socket
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:page_groups, page_groups)
  end

  @impl true
  def handle_event("do_import", _, socket) do
    {deleted, _ids} = ReimportArtworks.delete_existing_artworks()
    {created, errors} = ReimportArtworks.import_groups(socket.assigns.groups)

    {:noreply,
     socket
     |> assign(:imported, true)
     |> assign(:import_result, %{deleted: deleted, created: created, errors: errors})}
  end

  defp media_thumb(nil), do: nil

  defp media_thumb(filename) do
    media_index = get_media_index()

    case Map.get(media_index, filename) do
      nil ->
        nil

      {_id, path} ->
        MykonosBiennale.Uploads.media_url(
          %Media{source_type: "upload", source_path: path},
          size: "admin"
        )
    end
  end

  defp get_media_index do
    Process.get(:media_index) ||
      (
        idx = ReimportArtworks.build_media_index()
        Process.put(:media_index, idx)
        idx
      )
  end
end
