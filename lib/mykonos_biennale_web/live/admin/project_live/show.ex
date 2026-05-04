defmodule MykonosBiennaleWeb.Admin.ProjectLive.Show do
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
    project = Content.get_project!(id)
    events = get_project_events(project)
    participants = get_project_participants(project)

    {:noreply,
     socket
     |> assign(:page_title, pfield(project, "title") || "Project ##{project.id}")
     |> assign(:project, project)
     |> assign(:events, events)
     |> assign(:participants, participants)}
  end

  defp pfield(%Entity{fields: fields}, key, default \\ nil) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp pfield(_, _key, default), do: default

  defp get_project_events(project) do
    rt = Repo.get_by(RelationshipType, slug: "event_project")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^project.id and r.relationship_type_id == ^rt.id,
          preload: [:subject]
      )
      |> Enum.map(& &1.subject)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.fields["date"], :desc)
    else
      []
    end
  end

  defp get_project_participants(project) do
    ap_rt = Repo.get_by(RelationshipType, slug: "artwork_participant")
    ae_rt = Repo.get_by(RelationshipType, slug: "artwork_event")
    ep_rt = Repo.get_by(RelationshipType, slug: "event_project")

    cond do
      ap_rt == nil or ae_rt == nil or ep_rt == nil ->
        []

      true ->
        event_ids =
          Repo.all(
            from r in Relationship,
              where: r.object_id == ^project.id and r.relationship_type_id == ^ep_rt.id,
              select: r.subject_id
          )

        if event_ids == [] do
          []
        else
          artwork_ids =
            Repo.all(
              from r in Relationship,
                where: r.object_id in ^event_ids and r.relationship_type_id == ^ae_rt.id,
                select: r.subject_id
            )

          if artwork_ids == [] do
            []
          else
            participant_ids =
              Repo.all(
                from r in Relationship,
                  where: r.subject_id in ^artwork_ids and r.relationship_type_id == ^ap_rt.id,
                  select: r.object_id
              )
              |> Enum.uniq()

            if participant_ids == [] do
              []
            else
              Repo.all(from e in Entity, where: e.id in ^participant_ids)
              |> Enum.sort_by(fn p ->
                last = p.fields["last_name"] || ""
                first = p.fields["first_name"] || ""
                {last, first}
              end)
            end
          end
        end
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
        project = socket.assigns.project

        project
        |> Ecto.Changeset.change(fields: new_fields)
        |> Repo.update!()

        {:noreply, assign(socket, :project, %{project | fields: new_fields})}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
