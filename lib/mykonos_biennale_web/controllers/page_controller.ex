defmodule MykonosBiennaleWeb.PageController do
  use MykonosBiennaleWeb, :controller
  alias MykonosBiennale.Content
  alias MykonosBiennaleWeb.BiennaleController

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, EntityMedia, Relationship, RelationshipType}

  import Ecto.Query, warn: false

  @team_role_labels %{
    "curator" => "Curator",
    "producer" => "Producer",
    "director" => "Director",
    "coordinator" => "Coordinator",
    "designer" => "Designer",
    "technical" => "Technical",
    "volunteer" => "Volunteer"
  }

  def home(conn, _params) do
    current_biennale_year =
      Application.get_env(:mykonos_biennale, :current_biennale_year, 2021)

    current_biennale = Content.get_biennale_by_year(current_biennale_year)

    rt = preload_relationship_types()

    {raw_projects, raw_events} =
      if current_biennale do
        {
          list_projects_for_biennale(current_biennale, rt),
          list_events_for_biennale(current_biennale, rt)
        }
      else
        {[], []}
      end

    biennales = Content.list_biennales()

    # -- One relationship query for structure (event↔project, event→artwork/film, team) --
    structure = load_structure(current_biennale, raw_projects, raw_events, rt)

    # -- One relationship query for people (artwork→participant, film→director) --
    people = load_people(structure.artwork_ids, structure.film_ids, rt)

    # -- Media batch (entity_media + media in 2 queries), includes team headshots --
    all_entity_ids =
      [
        current_biennale && current_biennale.id,
        Enum.map(raw_projects, & &1.id),
        Enum.map(raw_events, & &1.id),
        Enum.map(biennales, & &1.id),
        Enum.map(structure.team_members, & &1.id)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    media_links_by_entity = batch_media_links(all_entity_ids)
    media_by_entity = map_media_from_links(media_links_by_entity)

    # -- Derive everything else in Elixir (no more queries) --
    project_media =
      Map.new(raw_projects, fn p ->
        media = Map.get(media_by_entity, p.id, [])

        media =
          if media == [],
            do: fallback_project_media(p.id, structure.project_event_ids, media_by_entity),
            else: media

        {p.id, media}
      end)

    project_participants =
      derive_project_people(
        raw_projects,
        structure.project_event_ids,
        structure.event_artwork_map,
        people.artwork_participants
      )

    project_directors =
      derive_project_people(
        raw_projects,
        structure.project_event_ids,
        structure.event_film_map,
        people.film_directors
      )

    event_participants = derive_event_people(raw_events, structure.event_artwork_map, people.artwork_participants)

    projects =
      Enum.map(
        raw_projects,
        &present_project(&1, media_by_entity, structure, project_participants, project_directors)
      )

    events =
      Enum.map(raw_events, &present_event(&1, media_by_entity, structure, event_participants))

    project_event_map =
      events
      |> Enum.filter(& &1[:project_id])
      |> Enum.into(%{}, fn event -> {event.project_id, event.id} end)

    biennale_media =
      if current_biennale, do: Map.get(media_by_entity, current_biennale.id, []), else: []

    biennale_links =
      if current_biennale, do: Map.get(media_links_by_entity, current_biennale.id, []), else: []

    statement_bg_media =
      find_media_by_role(biennale_links, "statement_bg") || List.first(biennale_media)

    program_bg_media =
      find_media_by_role(biennale_links, "program_bg") || Enum.at(biennale_media, 1)

    sponsors = load_sponsors(biennale_links)

    team_members = attach_team_photos(structure.team_members, media_links_by_entity)

    biennale_media_map =
      Map.new(biennales, fn b -> {b.id, Map.get(media_by_entity, b.id, [])} end)

    conn
    |> assign(:page_title, page_title(current_biennale))
    |> assign(:biennale, current_biennale)
    |> assign(:projects, projects)
    |> assign(:events, events)
    |> assign(:biennales, biennales)
    |> assign(:biennale_media, biennale_media)
    |> assign(:statement_bg_media, statement_bg_media)
    |> assign(:program_bg_media, program_bg_media)
    |> assign(:biennale_media_map, biennale_media_map)
    |> assign(:project_media, project_media)
    |> assign(:project_event_map, project_event_map)
    |> assign(:team_members, team_members)
    |> assign(:sponsors, sponsors)
    |> put_view(MykonosBiennaleWeb.BiennaleHTML)
    |> BiennaleController.render_template(current_biennale)
  end

  # -- Presentation --

  defp present_project(entity, media_by_entity, structure, project_participants, project_directors) do
    media = Map.get(media_by_entity, entity.id, [])

    media =
      if media == [],
        do: fallback_project_media(entity.id, structure.project_event_ids, media_by_entity),
        else: media

    %{
      id: entity.id,
      title: entity.fields["title"],
      description: entity.fields["description"],
      statement: entity.fields["statement"],
      slug: entity.slug,
      background_image: extract_background(media),
      participants: Map.get(project_participants, entity.id, []),
      directors: Map.get(project_directors, entity.id, [])
    }
  end

  defp present_event(entity, media_by_entity, structure, event_participants) do
    media = Map.get(media_by_entity, entity.id, [])

    %{
      id: entity.id,
      title: entity.fields["title"],
      type: entity.fields["type"],
      date: entity.fields["date"],
      time: entity.fields["time"],
      location: entity.fields["location"],
      description: entity.fields["description"],
      slug: entity.slug,
      background_image: extract_background(media),
      project_id: Map.get(structure.event_project_map, entity.id),
      participants: Map.get(event_participants, entity.id, [])
    }
  end

  defp extract_background(media) do
    case List.last(media) do
      %{source_type: "upload"} = m ->
        MykonosBiennale.Uploads.media_url(m, size: "card")

      %{source_type: "url", source_url: url} when is_binary(url) ->
        url

      _ ->
        nil
    end
  end

  # -- Queries (9 total for the home page) --

  defp preload_relationship_types do
    slugs = [
      "biennale_event",
      "event_project",
      "artwork_event",
      "artwork_participant",
      "directed",
      "screened_at",
      "biennale_team"
    ]

    Repo.all(from rt in RelationshipType, where: rt.slug in ^slugs)
    |> Enum.into(%{}, fn rt -> {rt.slug, rt} end)
  end

  defp list_projects_for_biennale(biennale, rt) do
    be_rt = Map.get(rt, "biennale_event")
    ep_rt = Map.get(rt, "event_project")

    if be_rt && ep_rt do
      Repo.all(
        from p in Entity,
          join: ep in Relationship,
          on: ep.relationship_type_id == ^ep_rt.id and ep.object_id == p.id,
          join: be in Relationship,
          on: be.relationship_type_id == ^be_rt.id and be.subject_id == ep.subject_id,
          where: p.type == "project" and be.object_id == ^biennale.id,
          distinct: p.id,
          order_by: [asc: p.identity]
      )
    else
      []
    end
  end

  defp list_events_for_biennale(biennale, rt) do
    be_rt = Map.get(rt, "biennale_event")

    if be_rt do
      Repo.all(
        from e in Entity,
          join: r in Relationship,
          on: r.subject_id == e.id,
          where: e.type == "event" and r.object_id == ^biennale.id and r.relationship_type_id == ^be_rt.id,
          order_by: [desc: e.inserted_at]
      )
    else
      []
    end
  end

  # One query: all structural relationships for this biennale's entities.
  # Picks up event↔project (ep), event→artwork (ae), event→film (sa/screened_at)
  # and biennale→team (bt) in a single round-trip, with entities preloaded.
  defp load_structure(nil, _raw_projects, _raw_events, _rt) do
    %{
      event_project_map: %{},
      project_event_ids: %{},
      event_artwork_map: %{},
      event_film_map: %{},
      artwork_ids: [],
      film_ids: [],
      team_members: []
    }
  end

  defp load_structure(biennale, raw_projects, raw_events, rt) do
    event_ids = Enum.map(raw_events, & &1.id)
    project_ids = Enum.map(raw_projects, & &1.id)
    base_ids = [biennale.id | event_ids ++ project_ids]

    rt_ids =
      [
        Map.get(rt, "event_project"),
        Map.get(rt, "artwork_event"),
        Map.get(rt, "screened_at"),
        Map.get(rt, "biennale_team")
      ]
      |> Enum.map(& &1 && &1.id)
      |> Enum.reject(&is_nil/1)

    rels =
      Repo.all(
        from r in Relationship,
          where: r.relationship_type_id in ^rt_ids and (r.subject_id in ^base_ids or r.object_id in ^base_ids),
          preload: [:subject, :object]
      )

    ep_rt = Map.get(rt, "event_project")
    ae_rt = Map.get(rt, "artwork_event")
    sa_rt = Map.get(rt, "screened_at")
    bt_rt = Map.get(rt, "biennale_team")

    ep_rels = ep_rt && Enum.filter(rels, &(&1.relationship_type_id == ep_rt.id))
    ae_rels = ae_rt && Enum.filter(rels, &(&1.relationship_type_id == ae_rt.id))
    sa_rels = sa_rt && Enum.filter(rels, &(&1.relationship_type_id == sa_rt.id))
    bt_rels = bt_rt && Enum.filter(rels, &(&1.relationship_type_id == bt_rt.id))

    ep_rels = ep_rels || []
    ae_rels = ae_rels || []
    sa_rels = sa_rels || []

    event_project_map =
      ep_rels
      |> Enum.map(&{&1.subject_id, &1.object_id})
      |> Enum.into(%{})

    project_event_ids =
      ep_rels
      |> Enum.group_by(& &1.object_id, & &1.subject_id)

    event_artwork_map =
      ae_rels
      |> Enum.group_by(& &1.object_id, & &1.subject_id)

    event_film_map =
      sa_rels
      |> Enum.group_by(& &1.object_id, & &1.subject_id)

    artwork_ids = ae_rels |> Enum.map(& &1.subject_id) |> Enum.uniq()
    film_ids = sa_rels |> Enum.map(& &1.subject_id) |> Enum.uniq()

    team_members =
      case bt_rels do
        nil -> []
        rels -> Enum.map(rels, &team_member_from_rel/1)
      end

    %{
      event_project_map: event_project_map,
      project_event_ids: project_event_ids,
      event_artwork_map: event_artwork_map,
      event_film_map: event_film_map,
      artwork_ids: artwork_ids,
      film_ids: film_ids,
      team_members: team_members
    }
  end

  # One query: artwork→participant and film→director relationships with
  # participant entities preloaded (replaces separate participant/director
  # entity lookups).
  defp load_people([], [], _rt) do
    %{artwork_participants: %{}, film_directors: %{}}
  end

  defp load_people(artwork_ids, film_ids, rt) do
    ap_rt = Map.get(rt, "artwork_participant")
    directed_rt = Map.get(rt, "directed")

    subject_ids = Enum.uniq(artwork_ids ++ film_ids)

    rt_ids =
      [ap_rt && ap_rt.id, directed_rt && directed_rt.id]
      |> Enum.reject(&is_nil/1)

    rels =
      Repo.all(
        from r in Relationship,
          where: r.relationship_type_id in ^rt_ids and r.subject_id in ^subject_ids,
          preload: [:object]
      )

    artwork_participants =
      rels
      |> Enum.filter(&(ap_rt && &1.relationship_type_id == ap_rt.id))
      |> Enum.group_by(& &1.subject_id)
      |> Map.new(fn {artwork_id, rels} ->
        people = Enum.map(rels, &{&1.object.id, &1.object.identity})
        {artwork_id, Enum.uniq(people)}
      end)

    film_directors =
      rels
      |> Enum.filter(&(directed_rt && &1.relationship_type_id == directed_rt.id))
      |> Enum.group_by(& &1.subject_id)
      |> Map.new(fn {film_id, rels} ->
        people = Enum.map(rels, &{&1.object.id, &1.object.identity})
        {film_id, Enum.uniq(people)}
      end)

    %{artwork_participants: artwork_participants, film_directors: film_directors}
  end

  defp batch_media_links([]), do: %{}

  defp batch_media_links(entity_ids) do
    records =
      Repo.all(
        from em in EntityMedia,
          where: em.entity_id in ^entity_ids,
          order_by: [asc: em.entity_id, asc: em.position],
          preload: [:media]
      )

    Enum.group_by(records, & &1.entity_id)
  end

  # -- Elixir-only derivations (zero queries) --

  defp derive_project_people(raw_projects, project_event_ids, event_work_map, work_people) do
    Map.new(raw_projects, fn project ->
      event_ids = Map.get(project_event_ids, project.id, [])
      work_ids = Enum.flat_map(event_ids, &Map.get(event_work_map, &1, []))
      people = Enum.flat_map(work_ids, &Map.get(work_people, &1, []))
      {project.id, Enum.uniq(people)}
    end)
  end

  defp derive_event_people(raw_events, event_artwork_map, artwork_participants) do
    Map.new(raw_events, fn event ->
      artwork_ids = Map.get(event_artwork_map, event.id, [])
      people = Enum.flat_map(artwork_ids, &Map.get(artwork_participants, &1, []))
      {event.id, Enum.uniq(people)}
    end)
  end

  defp team_member_from_rel(rel) do
    participant = rel.object
    role = rel.fields && rel.fields["role"]

    %{
      id: participant.id,
      name: participant.identity,
      role: role,
      role_label: Map.get(@team_role_labels, role, role),
      photo: nil
    }
  end

  defp attach_team_photos(team_members, media_links_by_entity) do
    Enum.map(team_members, fn member ->
      photo =
        media_links_by_entity
        |> Map.get(member.id, [])
        |> Enum.find_value(fn link ->
          if link.metadata && link.metadata["role"] == "headshot", do: link.media
        end)

      %{member | photo: photo}
    end)
  end

  defp fallback_project_media(project_id, project_event_ids, media_by_entity) do
    event_ids = Map.get(project_event_ids, project_id, [])
    Enum.flat_map(event_ids, fn eid -> Map.get(media_by_entity, eid, []) end)
  end

  defp map_media_from_links(links_by_entity) do
    Map.new(links_by_entity, fn {id, links} -> {id, Enum.map(links, & &1.media)} end)
  end

  defp find_media_by_role(links, role) do
    Enum.find_value(links, fn link ->
      if link.metadata && link.metadata["role"] == role, do: link.media
    end)
  end

  defp load_sponsors(links) do
    Enum.filter(links, fn link -> link.metadata && link.metadata["role"] == "sponsor" end)
    |> Enum.map(fn link ->
      %{
        media_id: link.media_id,
        media: link.media,
        name: link.metadata["name"] || link.media.caption || "",
        url: link.metadata["url"] || ""
      }
    end)
  end

  defp page_title(nil), do: "Mykonos Biennale"
  defp page_title(biennale), do: "Mykonos Biennale #{biennale.fields["year"]}"
end
