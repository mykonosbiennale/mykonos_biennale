defmodule MykonosBiennaleWeb.Admin.MediaLive.Rotate do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.{Repo, Content}
  alias MykonosBiennale.Content.{Media, EntityMedia}
  alias MykonosBiennale.Workers.MediaProcess
  alias MykonosBiennale.Uploads

  @per_page 200

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
      socket
      |> assign(:selected, MapSet.new())
      |> assign(:search, "")
      |> assign(:current_page, 1)
      |> assign(:total_pages, 1)
      |> assign(:total_count, 0)
      |> assign(:page_title, "Batch Rotate Media")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || socket.assigns.search

    {items, total_count} = list_upload_media(page, @per_page, search)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:search, search)
      |> assign(:items, items)}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, id_int),
        do: MapSet.delete(selected, id_int),
        else: MapSet.put(selected, id_int)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.items, & &1.id)
    {:noreply, assign(socket, :selected, MapSet.new(all_ids))}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected, MapSet.new())}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, push_patch(socket, to: "/admin/media/rotate?search=#{URI.encode_www_form(search)}")}
  end

  def handle_event("rotate_selected", %{"degrees" => degrees}, socket) do
    selected = socket.assigns.selected

    if MapSet.size(selected) == 0 do
      {:noreply, put_flash(socket, :error, "Select at least one image to rotate")}
    else
      deg = String.to_integer(degrees)

      selected
      |> Enum.each(fn media_id ->
        MediaProcess.enqueue_rotate(media_id, deg)
      end)

      {:noreply,
        socket
        |> assign(:selected, MapSet.new())
        |> put_flash(:info, "Rotation #{deg}° queued for #{MapSet.size(selected)} images")}
    end
  end

  defp list_upload_media(page, per_page, search) do
    offset = (page - 1) * per_page

    base_query =
      from m in Media,
        where: m.source_type == "upload" and not is_nil(m.source_path),
        where:
          fragment("lower(coalesce(?, '')) LIKE ?", m.original_name, ^"%#{String.downcase(search)}%") or
            fragment("lower(coalesce(?, '')) LIKE ?", m.caption, ^"%#{String.downcase(search)}%")

    total_count = Repo.aggregate(base_query, :count)

    items =
      Repo.all(
        from m in base_query,
          order_by: [desc: m.id],
          limit: ^per_page,
          offset: ^offset
      )

    {items, total_count}
  end

  defp media_thumb(media), do: Uploads.media_url(media, size: "card")

  defp rotation_label(%Media{metadata: %{"rotation" => r}}) when r > 0, do: "#{r}°"
  defp rotation_label(_), do: nil
end
