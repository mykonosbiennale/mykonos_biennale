defmodule MykonosBiennaleWeb.Admin.BiennaleLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Biennales")
     |> stream(:biennales, Content.list_biennales())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Biennale")
    |> assign(:biennale, Content.get_biennale!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Biennale")
    |> assign(:biennale, Content.get_biennale!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Biennale")
    |> assign(:biennale, %Content.Entity{type: "biennale", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Biennales")
    |> assign(:biennale, nil)
  end

  def handle_info(
        {MykonosBiennaleWeb.Admin.BiennaleLive.FormComponent, {:flash, kind, message}},
        socket
      ) do
    {:noreply, put_flash(socket, kind, message)}
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.BiennaleLive.FormComponent, {:saved, biennale}},
        socket
      ) do
    {:noreply, stream_insert(socket, :biennales, biennale)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    biennale = Content.get_biennale!(id)
    {:ok, _} = Content.delete_biennale(biennale)

    {:noreply, stream_delete(socket, :biennales, biennale)}
  end

  # Template helpers (this LiveView renders `MykonosBiennale.Content.Entity` records where
  # the domain fields live under `entity.fields` with string keys).
  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default

  defp parse_date(%Date{} = date), do: {:ok, date}
  defp parse_date(nil), do: :error

  defp parse_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> {:ok, d}
      _ -> :error
    end
  end

  defp parse_date(_), do: :error

  defp format_date(date, format) do
    case parse_date(date) do
      {:ok, d} -> Calendar.strftime(d, format)
      :error -> nil
    end
  end

  defp format_biennale_date_range(%Content.Entity{} = biennale) do
    start_s = format_date(field(biennale, "start_date"), "%b %d")
    end_s = format_date(field(biennale, "end_date"), "%b %d, %Y")

    case {start_s, end_s} do
      {nil, nil} -> nil
      {nil, e} -> e
      {s, nil} -> s
      {s, e} -> "#{s} - #{e}"
    end
  end

  # Placeholder until we want to show actual event counts without N+1 queries.
  defp event_count(_biennale), do: 0
end
