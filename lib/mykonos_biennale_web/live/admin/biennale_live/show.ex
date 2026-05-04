defmodule MykonosBiennaleWeb.Admin.BiennaleLive.Show do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:active_tab, "default")}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    biennale = Content.get_biennale!(id)
    events = get_biennale_events(biennale)

    {:noreply,
     socket
     |> assign(:page_title, pfield(biennale, "year") || "Biennale ##{biennale.id}")
     |> assign(:biennale, biennale)
     |> assign(:events, events)}
  end

  defp pfield(entity, key, default \\ nil)

  defp pfield(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp pfield(_, _key, default), do: default

  defp get_biennale_events(biennale) do
    rt = Repo.get_by(RelationshipType, slug: "biennale_event")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^biennale.id and r.relationship_type_id == ^rt.id,
          preload: [:subject]
      )
      |> Enum.map(& &1.subject)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.fields["date"], :desc)
    else
      []
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_info({:fields_changed, %{content: content}}, socket) do
    case Jason.decode(content) do
      {:ok, new_fields} ->
        biennale = socket.assigns.biennale

        biennale
        |> Ecto.Changeset.change(fields: new_fields)
        |> Repo.update!()

        {:noreply, assign(socket, :biennale, %{biennale | fields: new_fields})}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp format_date(nil), do: nil

  defp format_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> Calendar.strftime(d, "%B %d, %Y")
      _ -> date
    end
  end

  defp format_date(%Date{} = d), do: Calendar.strftime(d, "%B %d, %Y")
end
