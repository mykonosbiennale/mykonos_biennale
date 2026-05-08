defmodule MykonosBiennaleWeb.Admin.EventLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}
  alias MykonosBiennale.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Events")
     |> assign(:search, "")
     |> stream(:events, list_events_filtered(""))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Event") |> assign(:event, Content.get_event_for_admin!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket |> assign(:page_title, "Show Event") |> assign(:event, Content.get_event_for_admin!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Event") |> assign(:event, %Content.Entity{type: "event", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Events") |> assign(:event, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.EventLive.FormComponent, {:saved, event}}, socket) do
    event = Content.get_event_for_admin!(event.id)
    {:noreply, stream_insert(socket, :events, event)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Content.get_event!(id)
    {:ok, _} = Content.delete_event(event)
    {:noreply, stream_delete(socket, :events, event)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> stream(:events, list_events_filtered(term), reset: true)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> stream(:events, list_events_filtered(""), reset: true)}
  end

  defp list_events_filtered(""), do: Content.list_events_for_admin()
  defp list_events_filtered(term) do
    pattern = Search.entity_search_pattern(term)
    rel_query = admin_relationship_query()

    Repo.all(
      from e in Entity,
        where: e.type == "event",
        where: not is_nil(e.search_index) and like(e.search_index, ^pattern),
        order_by: [asc: fragment("? ->> ?", e.fields, "date")],
        preload: [as_subject: ^rel_query]
    )
  end

  defp admin_relationship_query do
    rt_ids =
      from rt in RelationshipType,
        where: rt.slug in ^["biennale_event", "event_festival", "event_project"],
        select: rt.id

    from r in Relationship,
      where: r.relationship_type_id in subquery(rt_ids),
      preload: [:object, :relationship_type]
  end

  defp field(entity, key, default \\ nil)
  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end
  defp field(%Content.Entity{}, _key, default), do: default

  defp event_biennale(%Content.Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, &rel_type_slug?(&1, "biennale_event")) do
      %Relationship{object: %Content.Entity{} = biennale} -> biennale
      _ -> nil
    end
  end
  defp event_biennale(%Content.Entity{}), do: nil

  defp event_project(%Content.Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, &rel_type_slug?(&1, "event_project")) do
      %Relationship{object: %Content.Entity{} = project} -> project
      _ -> nil
    end
  end
  defp event_project(%Content.Entity{}), do: nil

  defp rel_type_slug?(%Relationship{relationship_type: %RelationshipType{slug: slug}}, slug), do: true
  defp rel_type_slug?(_, _), do: false

  defp parse_date(%Date{} = date), do: {:ok, date}
  defp parse_date(nil), do: :error
  defp parse_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> {:ok, d}
      _ -> :error
    end
  end
  defp parse_date(_), do: :error

  defp format_event_date(%Content.Entity{} = event) do
    case parse_date(field(event, "date")) do
      {:ok, d} -> Calendar.strftime(d, "%b %d, %Y")
      :error -> nil
    end
  end
end
