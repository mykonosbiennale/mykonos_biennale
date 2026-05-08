defmodule MykonosBiennaleWeb.Admin.ParticipantLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Participants")
     |> assign(:search, "")
     |> stream(:participants, list_participants_filtered(""))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Participant") |> assign(:participant, Content.get_participant!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket |> assign(:page_title, "Show Participant") |> assign(:participant, Content.get_participant!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Participant") |> assign(:participant, %Content.Entity{type: "participant", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Participants") |> assign(:participant, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.ParticipantLive.FormComponent, {:saved, participant}}, socket) do
    {:noreply, stream_insert(socket, :participants, participant)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    participant = Content.get_participant!(id)
    {:ok, _} = Content.delete_participant(participant)
    {:noreply, stream_delete(socket, :participants, participant)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> stream(:participants, list_participants_filtered(term), reset: true)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> stream(:participants, list_participants_filtered(""), reset: true)}
  end

  defp list_participants_filtered(""), do: Content.list_participants()
  defp list_participants_filtered(term) do
    pattern = Search.entity_search_pattern(term)

    Repo.all(
      from e in Entity,
        where: e.type == "participant",
        where: not is_nil(e.search_index) and like(e.search_index, ^pattern),
        order_by: [asc: fragment("? ->> ?", e.fields, "last_name")]
    )
  end

  defp field(entity, key, default \\ nil)
  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end
  defp field(%Content.Entity{}, _key, default), do: default
end
