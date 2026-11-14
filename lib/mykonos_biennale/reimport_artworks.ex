defmodule MykonosBiennale.ReimportArtworks do
  @moduledoc """
  Reimports artworks from the festival export, grouping duplicates by
  (title_slug, year, project_slug, artist_name). Relinks existing media
  records by matching original_name to the export file paths.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.EntityMedia
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Content.RelationshipType
  alias MykonosBiennale.Repo

  @records_path "exports/festival/records.json"

  # Overridable in tests via config :mykonos_biennale, :reimport_records_path.
  def records_path do
    Application.get_env(:mykonos_biennale, :reimport_records_path) ||
      Path.join(File.cwd!(), @records_path)
  end

  # A missing export is treated as "no records" so the admin preview renders
  # an empty state instead of crashing.
  def load_export do
    path = records_path()

    case File.read(path) do
      {:ok, raw} -> Jason.decode!(raw)
      {:error, _} -> []
    end
  end

  def build_groups do
    records = load_export()
    maps = build_lookup_maps(records)

    records
    |> Enum.filter(&(&1["model"] == "festival.art"))
    |> Enum.group_by(&group_key(&1, maps))
    |> Enum.map(fn {key, items} -> build_group(key, items, maps) end)
    |> Enum.sort_by(fn g -> {g.artist_name, g.year, g.title} end)
  end

  defp build_lookup_maps(records) do
    %{
      projects: index_by_pk(records, "festival.project"),
      projectseasons: index_by_pk(records, "festival.projectseason"),
      artists: index_by_pk(records, "festival.artist"),
      festivals: index_by_pk(records, "festival.festival")
    }
  end

  defp index_by_pk(records, model) do
    for record <- records, record["model"] == model, into: %{}, do: {record["pk"], record}
  end

  defp group_key(art, maps) do
    title_slug = slugify(art["fields"]["title"] || "")

    {title_slug, art_year(art, maps), art_project_slug(art, maps), art_artist_name(art, maps)}
  end

  defp art_project_slug(art, maps) do
    project = Map.get(maps.projects, get_in(art, ["foreign_keys", "project", "pk"]))
    (project && project["fields"]["slug"]) || ""
  end

  defp art_year(art, maps) do
    ps = Map.get(maps.projectseasons, get_in(art, ["foreign_keys", "project_x", "pk"]))
    fest_pk = ps && get_in(ps, ["foreign_keys", "festival", "pk"])
    festival = fest_pk && Map.get(maps.festivals, fest_pk)
    (festival && to_string(festival["fields"]["year"])) || ""
  end

  defp art_artist_name(art, maps) do
    artist = Map.get(maps.artists, get_in(art, ["foreign_keys", "artist", "pk"]))
    (artist && artist["fields"]["name"]) || ""
  end

  defp build_group({title_slug, year, project_slug, artist_name} = key, items, maps) do
    first = items |> Enum.sort_by(& &1["pk"]) |> hd()

    %{
      key: key,
      title: first["fields"]["title"] || "Untitled",
      title_slug: title_slug,
      year: year,
      project_slug: project_slug,
      artist_name: artist_name,
      biennale_title:
        get_biennale_title(items, maps.projects, maps.projectseasons, maps.festivals),
      count: length(items),
      pks: Enum.map(items, & &1["pk"]),
      file_names: items |> Enum.flat_map(&item_file_names/1) |> Enum.uniq(),
      description: best_description(items),
      photo_url: first["fields"]["photo"],
      art_type: infer_art_type(project_slug),
      leader: Enum.any?(items, &(&1["fields"]["leader"] == true))
    }
  end

  defp item_file_names(art) do
    (art["files"] || [])
    |> Enum.map(fn f -> f |> Map.get("path", "") |> String.split("/") |> List.last() end)
    |> Enum.reject(&(&1 in ["", nil]))
  end

  defp get_biennale_title(items, project_map, _ps_map, fest_map) do
    art = hd(items)
    project_pk = get_in(art, ["foreign_keys", "project", "pk"])
    project = Map.get(project_map, project_pk)
    fest_pk = project && get_in(project, ["foreign_keys", "festival", "pk"])
    festival = fest_pk && Map.get(fest_map, fest_pk)
    (festival && festival["fields"]["title"]) || ""
  end

  defp best_description(items) do
    Enum.find_value(items, fn art ->
      d = art["fields"]["description"]
      if d && String.trim(d) != "", do: String.trim(d), else: nil
    end) || ""
  end

  @art_type_inference %{
    "dramatic-nights" => "performance",
    "video-graffiti" => "video",
    "film-festival" => "film",
    "manilapdfmpeg" => "film",
    "kite-festival" => "artwork",
    "treasure-hunt" => "artwork",
    "archaeological-museum" => "artwork",
    "a-night-of-philosophy" => "event",
    "trans-allegoria" => "artwork",
    "andromeda" => "artwork",
    "ocean-masks" => "artwork",
    "metamorphosis" => "artwork",
    "art-spell" => "artwork",
    "the-wind-igloo-project" => "artwork",
    "mirror-mirror" => "artwork",
    "birth-of-a-bubble" => "artwork",
    "epivatikos-stathmos" => "artwork",
    "idols-and-ideas" => "artwork",
    "flags" => "artwork",
    "the-greek-caribbean-cultural-exchange" => "artwork",
    "performance" => "performance",
    "the-house-on-matoyianni-street" => "artwork",
    "garden-of-mysteries" => "artwork",
    "animation" => "film",
    "urban" => "artwork",
    "antidote" => "artwork"
  }

  defp infer_art_type(slug) do
    Map.get(@art_type_inference, slug, "artwork")
  end

  def build_media_index do
    Repo.all(
      from m in Media,
        where: m.source_type == "upload" and like(m.original_name, "mykonos-biennale-%"),
        select: {m.original_name, m.id, m.source_path}
    )
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {name, rows} ->
      {^name, id, path} = Enum.min_by(rows, &elem(&1, 1))
      {name, id, path}
    end)
    |> Enum.into(%{}, fn {name, id, path} -> {name, {id, path}} end)
  end

  def delete_existing_artworks do
    artwork_ids =
      Repo.all(from e in Entity, where: e.type == "artwork", select: e.id)

    if artwork_ids != [] do
      ae_rt = Repo.one(from rt in RelationshipType, where: rt.slug == "artwork_event")
      ap_rt = Repo.one(from rt in RelationshipType, where: rt.slug == "artwork_participant")

      if ae_rt && ap_rt do
        Repo.delete_all(
          from r in Relationship,
            where:
              (r.subject_id in ^artwork_ids and r.relationship_type_id == ^ae_rt.id) or
                (r.subject_id in ^artwork_ids and r.relationship_type_id == ^ap_rt.id)
        )
      end

      Repo.delete_all(from em in EntityMedia, where: em.entity_id in ^artwork_ids)
      Repo.delete_all(from e in Entity, where: e.id in ^artwork_ids)
    end

    {length(artwork_ids), artwork_ids}
  end

  def import_groups(groups) do
    media_index = build_media_index()

    artist_pk_to_id = build_artist_pk_to_participant_id()
    fest_to_biennale = build_festival_pk_to_biennale_id()
    proj_pk_to_event_id = build_project_pk_to_event_id(fest_to_biennale)

    results =
      for group <- groups do
        attrs = %{
          title: group.title,
          description: group.description,
          type: group.art_type,
          date: group.year,
          visible: true
        }

        case Content.create_artwork(attrs) do
          {:ok, artwork} ->
            updated_fields =
              artwork.fields
              |> Map.put("import_pks", Enum.map(group.pks, &to_string/1))
              |> Map.put("import_model", "festival.art")
              |> Map.put("leader", group.leader)
              |> Map.put("import_photo_url", group.photo_url)
              |> Map.put("reimported", true)

            artwork
            |> Ecto.Changeset.change(fields: updated_fields)
            |> Repo.update!()

            attach_participant(artwork, group, artist_pk_to_id)
            attach_event(artwork, group, proj_pk_to_event_id)
            link_media(artwork, group, media_index)

            {:ok, artwork}

          {:error, cs} ->
            {:error, cs}
        end
      end

    created = Enum.count(results, &match?({:ok, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))
    {created, errors}
  end

  defp link_media(artwork, group, media_index) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      group.file_names
      |> Enum.with_index()
      |> Enum.flat_map(fn {filename, idx} ->
        case Map.get(media_index, filename) do
          nil ->
            []

          {media_id, _path} ->
            [
              [
                entity_id: artwork.id,
                media_id: media_id,
                position: idx,
                metadata: %{},
                inserted_at: now,
                updated_at: now
              ]
            ]
        end
      end)

    if rows != [] do
      Repo.insert_all(EntityMedia, rows)
    end

    length(rows)
  end

  defp attach_participant(artwork, group, artist_pk_to_id) do
    for artist_pk <- group_pk_values(group, "artist") do
      case Map.get(artist_pk_to_id, artist_pk) do
        nil -> :ok
        participant_id -> attach_participant_once(artwork, participant_id)
      end
    end
  end

  defp attach_participant_once(artwork, participant_id) do
    participant = Content.get_participant!(participant_id)

    case Content.list_artwork_linked_participants(artwork)
         |> Enum.find(&(&1.id == participant_id)) do
      nil -> Content.attach_participant_to_artwork(artwork, participant, "creator")
      _ -> :ok
    end
  end

  defp attach_event(artwork, group, proj_pk_to_event_id) do
    for project_pk <- group_pk_values(group, "project") do
      case Map.get(proj_pk_to_event_id, project_pk) do
        nil -> :ok
        event_id -> attach_event_once(artwork, event_id)
      end
    end
  end

  defp attach_event_once(artwork, event_id) do
    event = Content.get_event!(event_id)

    case Content.list_artwork_linked_events(artwork)
         |> Enum.find(&(&1.id == event_id)) do
      nil -> Content.attach_event_to_artwork(artwork, event)
      _ -> :ok
    end
  end

  defp group_pk_values(group, foreign_key) do
    records = load_export()
    arts = Enum.filter(records, &(&1["model"] == "festival.art" and &1["pk"] in group.pks))

    arts
    |> Enum.map(&get_in(&1, ["foreign_keys", foreign_key, "pk"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp build_artist_pk_to_participant_id do
    Repo.all(
      from e in Entity,
        where:
          e.type == "participant" and
            fragment("? ->> 'import_model'", e.fields) == "festival.artist",
        select: {fragment("CAST(? ->> 'import_pk' AS INTEGER)", e.fields), e.id}
    )
    |> Enum.into(%{})
  end

  defp build_festival_pk_to_biennale_id do
    Repo.all(
      from e in Entity,
        where:
          e.type == "biennale" and
            fragment("? ->> 'import_model'", e.fields) == "festival.festival",
        select: {fragment("CAST(? ->> 'import_pk' AS INTEGER)", e.fields), e.id}
    )
    |> Enum.into(%{})
  end

  defp build_project_pk_to_event_id(fest_to_biennale) do
    events =
      Repo.all(
        from e in Entity,
          where: e.type == "event" and fragment("? ->> 'import_key' IS NOT NULL", e.fields),
          select: {fragment("? ->> 'import_key'", e.fields), e.id}
      )
      |> Enum.into(%{})

    records = load_export()
    projects = Enum.filter(records, &(&1["model"] == "festival.project"))

    slug_to_project = build_project_slug_to_id()

    projects
    |> Enum.reduce(%{}, fn proj, acc ->
      case project_event_id(proj, fest_to_biennale, slug_to_project, events) do
        nil -> acc
        event_id -> Map.put(acc, proj["pk"], event_id)
      end
    end)
  end

  defp project_event_id(proj, fest_to_biennale, slug_to_project, events) do
    fest_pk = get_in(proj["foreign_keys"], ["festival", "pk"])
    biennale_id = Map.get(fest_to_biennale, fest_pk)
    project_entity_id = Map.get(slug_to_project, normalize_slug(proj["fields"]["slug"]))

    if biennale_id && project_entity_id do
      Map.get(events, "#{biennale_id}-#{project_entity_id}")
    end
  end

  defp build_project_slug_to_id do
    Repo.all(
      from e in Entity,
        where:
          e.type == "project" and
            fragment("? ->> 'import_slug' IS NOT NULL", e.fields),
        select: {fragment("? ->> 'import_slug'", e.fields), e.id}
    )
    |> Enum.into(%{})
  end

  @slug_normalizations %{
    "antidode" => "treasure-hunt",
    "antidote" => "treasure-hunt",
    "archeological-museum" => "archaeological-museum",
    "lavra" => "flags"
  }

  defp normalize_slug(slug) do
    Map.get(@slug_normalizations, slug, slug)
  end

  defp slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, " ")
    |> String.replace(~r/[-_]+/u, " ")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
