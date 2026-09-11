defmodule MykonosBiennaleWeb.Admin.TeamLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

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
     |> assign(:page_title, "Team Members")
     |> assign(:team_roles, @team_roles)
     |> assign(:biennales, Content.list_biennales())
     |> assign(:participant_search, "")
     |> assign(:participant_results, [])
     |> assign(:selected_participant, nil)
     |> load_team()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add Team Member")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Team Members")
  end

  # -- Loading --

  defp load_team(socket) do
    bt_rt = Repo.get_by(RelationshipType, slug: "biennale_team")

    team =
      if bt_rt do
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^bt_rt.id,
            preload: [:subject, :object]
        )
        |> Enum.group_by(& &1.object_id)
        |> Enum.map(fn {participant_id, rels} ->
          participant = hd(rels).object

          memberships =
            Enum.map(rels, fn rel ->
              %{
                rel_id: rel.id,
                biennale_id: rel.subject_id,
                year: rel.subject && rel.subject.fields["year"],
                role: rel.fields && rel.fields["role"]
              }
            end)
            |> Enum.sort_by(&(-&1.year))

          %{participant_id: participant_id, name: participant.identity, memberships: memberships}
        end)
        |> Enum.sort_by(& &1.name)
      else
        []
      end

    assign(socket, :team, team)
  end

  # -- Events --

  @impl true
  def handle_event(
        "search_participants",
        %{"participant_search" => search, "_target" => _},
        socket
      ) do
    results =
      if String.trim(search) != "" do
        pattern = "%#{String.downcase(search)}%"
        existing_ids = Enum.map(socket.assigns.team, & &1.participant_id)

        Repo.all(
          from e in Entity,
            where:
              e.type == "participant" and
                e.id not in ^existing_ids and
                ilike(fragment("lower(?)", e.identity), ^pattern),
            limit: 10
        )
      else
        []
      end

    {:noreply,
     socket |> assign(:participant_search, search) |> assign(:participant_results, results)}
  end

  def handle_event("select_participant", %{"participant-id" => pid}, socket) do
    participant = Repo.get(Entity, pid)

    {:noreply,
     socket
     |> assign(:selected_participant, participant)
     |> assign(:participant_search, "")
     |> assign(:participant_results, [])}
  end

  def handle_event("clear_participant", _params, socket) do
    {:noreply, assign(socket, :selected_participant, nil)}
  end

  def handle_event("add_team_member", params, socket) do
    participant = socket.assigns.selected_participant
    role = params["role"]
    biennale_ids = biennale_ids_from_params(params)

    cond do
      is_nil(participant) ->
        {:noreply, put_flash(socket, :error, "Select a participant")}

      role == "" or is_nil(role) ->
        {:noreply, put_flash(socket, :error, "Select a role")}

      biennale_ids == [] ->
        {:noreply, put_flash(socket, :error, "Select at least one biennale")}

      true ->
        results =
          for bid <- biennale_ids do
            Content.create_relationship(%{
              slug: "biennale_team",
              subject_id: bid,
              object_id: participant.id,
              fields: %{"role" => role}
            })
          end

        if Enum.all?(results, &match?({:ok, _}, &1)) do
          {:noreply,
           socket
           |> load_team()
           |> assign(:selected_participant, nil)
           |> put_flash(:info, "Team member added to #{length(biennale_ids)} biennale(s)")
           |> push_patch(to: "/admin/teams")}
        else
          {:noreply, put_flash(socket, :error, "Could not add team member")}
        end
    end
  end

  def handle_event("update_role", %{"rel-id" => rel_id, "value" => role}, socket) do
    rel = Repo.get(Relationship, rel_id)

    if rel do
      rel
      |> Ecto.Changeset.change(fields: Map.put(rel.fields || %{}, "role", role))
      |> Repo.update()
    end

    {:noreply,
     socket
     |> load_team()
     |> put_flash(:info, "Role updated")}
  end

  def handle_event("remove_membership", %{"rel-id" => rel_id}, socket) do
    rel = Repo.get(Relationship, rel_id)
    if rel, do: {:ok, _} = Content.delete_relationship(rel)

    {:noreply,
     socket
     |> load_team()
     |> put_flash(:info, "Membership removed")}
  end

  def handle_event("delete", %{"participant-id" => pid}, socket) do
    bt_rt = Repo.get_by(RelationshipType, slug: "biennale_team")
    pid = String.to_integer(pid)

    if bt_rt do
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^pid and r.relationship_type_id == ^bt_rt.id
      )
      |> Enum.each(fn rel -> {:ok, _} = Content.delete_relationship(rel) end)
    end

    {:noreply,
     socket
     |> load_team()
     |> put_flash(:info, "Team member removed")}
  end

  defp biennale_ids_from_params(params) do
    params
    |> Enum.filter(fn {k, v} -> String.starts_with?(k, "biennale_") and v == "true" end)
    |> Enum.map(fn {k, _} -> String.replace_prefix(k, "biennale_", "") |> String.to_integer() end)
  end
end
