defmodule MykonosBiennale.Workers.ImportFestival do
  @moduledoc """
  Imports data from the old festival site export into the new schema.

  Source: exports/festival/records.json + exports/festival/media_manifest.json

  Each entity stores its original record in fields["original_record"] for reference.
  Import tracking via fields["import_pk"] and fields["import_model"].

  Run stages sequentially via iex:
    iex> ImportFestival.stage1()
    iex> ImportFestival.stage2()
    ...
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.Entity

  @records_path "exports/festival/records.json"

  defp load_records do
    path = Path.join(File.cwd!(), @records_path)

    if File.exists?(path) do
      {:ok, raw} = File.read(path)
      Jason.decode!(raw)
    else
      raise "Records file not found at #{path}"
    end
  end

  defp records_by_model(model) do
    load_records()
    |> Enum.filter(&(&1["model"] == model))
  end

  defp find_existing_by_type(model, pk, type) do
    pk_str = to_string(pk)

    Repo.one(
      from(e in Entity,
        where:
          e.type == ^type and
            fragment("? ->> 'import_model'", e.fields) == ^model and
            fragment("? ->> 'import_pk'", e.fields) == ^pk_str
      )
    )
  end

  defp find_existing_by_slug(slug, type) do
    Repo.one(
      from(e in Entity,
        where:
          e.type == ^type and
            fragment("? ->> 'import_slug'", e.fields) == ^slug
      )
    )
  end

  @doc """
  Stage 1: Import festivals as biennales.

  festival.festival → Biennale
  - year → year
  - title → theme
  - statement → statement
  """
  def stage1 do
    festivals = records_by_model("festival.festival")
    IO.puts("Stage 1: Importing #{length(festivals)} festivals as biennales...")

    results =
      for festival <- festivals do
        pk = festival["pk"]
        fields = festival["fields"]

        existing = find_existing_by_type("festival.festival", pk, "biennale")

        if existing do
          IO.puts("  Skipping festival PK #{pk} (already imported as biennale ID #{existing.id})")
          {:skipped, existing}
        else
          year = fields["year"]
          title = fields["title"]

          attrs = %{
            year: year,
            theme: title,
            statement: clean_string(fields["statement"]),
            visible: true
          }

          case Content.create_biennale(attrs) do
            {:ok, biennale} ->
              updated_fields =
                biennale.fields
                |> Map.put("original_record", festival)
                |> Map.put("import_pk", to_string(pk))
                |> Map.put("import_model", "festival.festival")

              biennale
              |> Ecto.Changeset.change(fields: updated_fields)
              |> Repo.update!()

              IO.puts("  Created biennale: #{year} - #{title} (ID #{biennale.id})")
              {:created, biennale}

            {:error, changeset} ->
              IO.puts("  ERROR creating biennale PK #{pk}: #{inspect(changeset.errors)}")
              {:error, changeset}
          end
        end
      end

    created = Enum.count(results, &match?({:created, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("\nStage 1 complete: #{created} created, #{skipped} skipped, #{errors} errors")

    :ok
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

  @doc """
  Stage 2: Import projects (deduped from festival.project + festival.projectx).

  Merges project and projectx records by slug. Applies normalizations:
  - "antidode" → "treasure-hunt" (typo)
  - "antidote" → "treasure-hunt" (same project per user)
  - "archeological-museum" → "archaeological-museum" (spelling)
  - "lavra" → "flags" (same project)

  Prefers projectx data when available (has statement field).
  """
  def stage2 do
    records = load_records()

    projects = Enum.filter(records, &(&1["model"] == "festival.project"))
    projectxs = Enum.filter(records, &(&1["model"] == "festival.projectx"))

    px_by_slug =
      projectxs
      |> Enum.reduce(%{}, fn px, acc ->
        slug = normalize_slug(px["fields"]["slug"])

        existing = Map.get(acc, slug)

        if existing == nil or
             (existing["fields"]["statement"] in [nil, "", " "] and
                px["fields"]["statement"] not in [nil, "", " "]) do
          Map.put(acc, slug, px)
        else
          acc
        end
      end)

    proj_by_slug =
      projects
      |> Enum.reduce(%{}, fn p, acc ->
        slug = normalize_slug(p["fields"]["slug"])
        if Map.has_key?(acc, slug), do: acc, else: Map.put(acc, slug, p)
      end)

    all_slugs =
      MapSet.union(MapSet.new(Map.keys(px_by_slug)), MapSet.new(Map.keys(proj_by_slug)))
      |> MapSet.to_list()
      |> Enum.sort()

    IO.puts("Stage 2: Importing #{length(all_slugs)} deduped projects...")

    results =
      for slug <- all_slugs do
        px = Map.get(px_by_slug, slug)
        proj = Map.get(proj_by_slug, slug)

        existing = find_existing_by_slug(slug, "project")

        cond do
          existing ->
            IO.puts("  Skipping #{slug} (already imported as project ID #{existing.id})")
            {:skipped, existing}

          true ->
            title = project_title(px, proj, slug)
            statement = clean_string(px && px["fields"]["statement"])

            original_records = %{
              "projectx" => px,
              "project" => proj
            }

            primary_pk = if px, do: px["pk"], else: proj["pk"]

            attrs = %{
              title: title,
              statement: statement,
              visible: true
            }

            case Content.create_project(attrs) do
              {:ok, project} ->
                updated_fields =
                  project.fields
                  |> Map.put("original_record", original_records)
                  |> Map.put("import_pk", to_string(primary_pk))
                  |> Map.put("import_model", "festival.projectx")
                  |> Map.put("import_slug", slug)

                project
                |> Ecto.Changeset.change(fields: updated_fields)
                |> Repo.update!()

                IO.puts("  Created project: #{title} (slug: #{slug}, ID #{project.id})")
                {:created, project}

              {:error, changeset} ->
                IO.puts("  ERROR creating project #{slug}: #{inspect(changeset.errors)}")
                {:error, changeset}
            end
        end
      end

    created = Enum.count(results, &match?({:created, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("\nStage 2 complete: #{created} created, #{skipped} skipped, #{errors} errors")

    :ok
  end

  defp project_title(px, proj, slug) do
    cond do
      px && px["fields"]["title"] not in [nil, ""] -> px["fields"]["title"]
      proj && proj["fields"]["title"] not in [nil, ""] -> proj["fields"]["title"]
      true -> String.replace(slug, "-", " ") |> String.capitalize()
    end
  end

  defp clean_string(nil), do: nil
  defp clean_string(""), do: nil
  defp clean_string(s) when is_binary(s), do: String.trim(s)
  defp clean_string(other), do: other

  defp build_festival_pk_to_biennale_id do
    Repo.all(
      from e in Entity,
        where:
          e.type == "biennale" and
            fragment("? ->> 'import_model'", e.fields) == "festival.festival",
        select: {fragment("? ->> 'import_pk'", e.fields), e.id}
    )
    |> Enum.into(%{}, fn {pk_str, id} -> {String.to_integer(pk_str), id} end)
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

  @event_type_mapping %{
    "dramatic-nights" => "performance",
    "video-graffiti" => "screening",
    "film-festival" => "screening",
    "manilapdfmpeg" => "screening",
    "kite-festival" => "festival",
    "treasure-hunt" => "exhibition",
    "archaeological-museum" => "exhibition",
    "a-night-of-philosophy" => "event",
    "trans-allegoria" => "exhibition",
    "andromeda" => "exhibition",
    "ocean-masks" => "exhibition",
    "metamorphosis" => "exhibition",
    "art-spell" => "exhibition",
    "the-wind-igloo-project" => "exhibition",
    "mirror-mirror" => "exhibition",
    "birth-of-a-bubble" => "exhibition",
    "epivatikos-stathmos" => "exhibition",
    "idols-and-ideas" => "exhibition",
    "flags" => "exhibition",
    "the-greek-caribbean-cultural-exchange" => "exhibition",
    "performance" => "performance",
    "the-house-on-matoyianni-street" => "event",
    "garden-of-mysteries" => "exhibition",
    "animation" => "screening",
    "urban" => "exhibition"
  }

  defp infer_event_type(slug) do
    Map.get(@event_type_mapping, slug, "event")
  end

  @doc """
  Stage 3: Import events from festival.project rows and projectseasons.

  Each festival.project row is a project-in-a-biennale = Event.
  Projectseasons are merged (some overlap with project rows).
  Dedup by (biennale_id, project_id) pair.

  Creates biennale_event and event_project relationships via Content.create_event.
  """
  def stage3 do
    records = load_records()

    projects = Enum.filter(records, &(&1["model"] == "festival.project"))
    projectseasons = Enum.filter(records, &(&1["model"] == "festival.projectseason"))

    fest_to_biennale = build_festival_pk_to_biennale_id()
    slug_to_project = build_project_slug_to_id()

    events_from_projects =
      projects
      |> Enum.map(fn proj ->
        fest_pk = get_in(proj["foreign_keys"], ["festival", "pk"])
        proj_slug = normalize_slug(proj["fields"]["slug"])

        biennale_id = Map.get(fest_to_biennale, fest_pk)
        project_id = Map.get(slug_to_project, proj_slug)

        {biennale_id, project_id, proj}
      end)
      |> Enum.filter(fn {biennale_id, project_id, _} ->
        biennale_id != nil and project_id != nil
      end)

    events_from_seasons =
      projectseasons
      |> Enum.map(fn ps ->
        fest_pk = get_in(ps["foreign_keys"], ["festival", "pk"])
        px_pk = get_in(ps["foreign_keys"], ["project", "pk"])

        biennale_id = Map.get(fest_to_biennale, fest_pk)

        projectx_records =
          Enum.filter(records, &(&1["model"] == "festival.projectx" and &1["pk"] == px_pk))

        px = List.first(projectx_records)
        proj_slug = if px, do: normalize_slug(px["fields"]["slug"]), else: nil
        project_id = if proj_slug, do: Map.get(slug_to_project, proj_slug), else: nil

        {biennale_id, project_id, ps}
      end)
      |> Enum.filter(fn {biennale_id, project_id, _} ->
        biennale_id != nil and project_id != nil
      end)

    all_events = events_from_projects ++ events_from_seasons

    deduped =
      all_events
      |> Enum.uniq_by(fn {biennale_id, project_id, _} -> {biennale_id, project_id} end)

    IO.puts(
      "Stage 3: Importing #{length(deduped)} events (from #{length(events_from_projects)} projects + #{length(events_from_seasons)} seasons)..."
    )

    results =
      for {biennale_id, project_id, source_record} <- deduped do
        proj_slug =
          case source_record do
            %{"fields" => %{"slug" => slug}} ->
              normalize_slug(slug)

            %{"foreign_keys" => %{"project" => %{"pk" => px_pk}}} ->
              px =
                List.first(
                  Enum.filter(
                    records,
                    &(&1["model"] == "festival.projectx" and &1["pk"] == px_pk)
                  )
                )

              if px, do: normalize_slug(px["fields"]["slug"]), else: "unknown"

            _ ->
              "unknown"
          end

        title =
          source_record["fields"]["title"] ||
            proj_slug |> String.replace("-", " ") |> String.capitalize()

        import_key = "#{biennale_id}-#{project_id}"

        existing = find_existing_by_import_key(import_key, "event")

        cond do
          existing ->
            IO.puts(
              "  Skipping event #{import_key} (already imported as event ID #{existing.id})"
            )

            {:skipped, existing}

          true ->
            biennale = Content.get_biennale!(biennale_id)
            year = biennale.fields["year"]

            attrs = %{
              title: title,
              type: infer_event_type(proj_slug),
              date: to_string(year),
              biennale_id: biennale_id,
              project_id: project_id,
              visible: true
            }

            case Content.create_event(attrs) do
              {:ok, event} ->
                updated_fields =
                  event.fields
                  |> Map.put("original_record", source_record)
                  |> Map.put("import_pk", to_string(source_record["pk"]))
                  |> Map.put("import_model", source_record["model"])
                  |> Map.put("import_key", import_key)
                  |> Map.put("import_slug", proj_slug)

                event
                |> Ecto.Changeset.change(fields: updated_fields)
                |> Repo.update!()

                IO.puts("  Created event: #{title} (#{year}, #{proj_slug}, ID #{event.id})")
                {:created, event}

              {:error, changeset} ->
                IO.puts("  ERROR creating event #{import_key}: #{inspect(changeset.errors)}")
                {:error, changeset}
            end
        end
      end

    created = Enum.count(results, &match?({:created, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("\nStage 3 complete: #{created} created, #{skipped} skipped, #{errors} errors")

    :ok
  end

  defp find_existing_by_import_key(import_key, type) do
    Repo.one(
      from e in Entity,
        where: e.type == ^type and fragment("? ->> 'import_key'", e.fields) == ^import_key
    )
  end

  defp split_name(name) when is_binary(name) do
    trimmed = String.trim(name)
    parts = String.split(trimmed, ~r/\s+/)

    case length(parts) do
      0 -> {"", ""}
      1 -> {"", hd(parts)}
      _ -> {Enum.join(Enum.take(parts, length(parts) - 1), " "), List.last(parts)}
    end
  end

  defp split_name(_), do: {"", ""}

  @doc """
  Stage 4: Import artists as participants.

  festival.artist → Participant
  - name → split into first_name + last_name
  - country → country
  - email → email
  - phone → phone
  - homepage → website
  - bio → bio
  - statement → statement
  - visible → visible (default true, false if old visible=false)

  Stores import_pk, import_model, import_slug, original_record in fields.
  """
  def stage4 do
    artists = records_by_model("festival.artist")
    IO.puts("Stage 4: Importing #{length(artists)} artists as participants...")

    results =
      for artist <- artists do
        pk = artist["pk"]
        fields = artist["fields"]

        existing = find_existing_by_type("festival.artist", pk, "participant")

        if existing do
          IO.puts(
            "  Skipping artist PK #{pk} (already imported as participant ID #{existing.id})"
          )

          {:skipped, existing}
        else
          raw_name = fields["name"] || ""
          {first_name, last_name} = split_name(raw_name)
          name = String.trim(raw_name)

          old_slug = fields["slug"]

          attrs = %{
            first_name: first_name,
            last_name: last_name,
            name: name,
            country: clean_string(fields["country"]),
            email: clean_string(fields["email"]),
            phone: clean_string(fields["phone"]),
            website: clean_string(fields["homepage"]),
            bio: clean_string(fields["bio"]),
            statement: clean_string(fields["statement"]),
            visible: fields["visible"] != false
          }

          case Content.create_participant(attrs) do
            {:ok, participant} ->
              updated_fields =
                participant.fields
                |> Map.put("original_record", artist)
                |> Map.put("import_pk", to_string(pk))
                |> Map.put("import_model", "festival.artist")
                |> Map.put("import_slug", old_slug)
                |> Map.put("import_event", fields["event"])

              participant
              |> Ecto.Changeset.change(fields: updated_fields)
              |> Repo.update!()

              IO.puts("  Created participant: #{name} (PK #{pk}, ID #{participant.id})")
              {:created, participant}

            {:error, changeset} ->
              IO.puts(
                "  ERROR creating artist PK #{pk} (#{raw_name}): #{inspect(changeset.errors)}"
              )

              {:error, changeset}
          end
        end
      end

    created = Enum.count(results, &match?({:created, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("\nStage 4 complete: #{created} created, #{skipped} skipped, #{errors} errors")

    :ok
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

  defp build_project_pk_to_event_id(fest_to_biennale) do
    events =
      Repo.all(
        from e in Entity,
          where:
            e.type == "event" and
              fragment("? ->> 'import_key' IS NOT NULL", e.fields),
          select: {fragment("? ->> 'import_key'", e.fields), e.id}
      )
      |> Enum.into(%{})

    records = load_records()
    projects = Enum.filter(records, &(&1["model"] == "festival.project"))

    slug_to_project = build_project_slug_to_id()

    projects
    |> Enum.reduce(%{}, fn proj, acc ->
      fest_pk = get_in(proj["foreign_keys"], ["festival", "pk"])
      biennale_id = Map.get(fest_to_biennale, fest_pk)
      proj_slug = normalize_slug(proj["fields"]["slug"])
      project_entity_id = Map.get(slug_to_project, proj_slug)
      proj_pk = proj["pk"]

      if biennale_id && project_entity_id do
        import_key = "#{biennale_id}-#{project_entity_id}"
        event_id = Map.get(events, import_key)

        if event_id do
          Map.put(acc, proj_pk, event_id)
        else
          acc
        end
      else
        acc
      end
    end)
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
    "urban" => "artwork"
  }

  defp infer_art_type(slug) do
    Map.get(@art_type_inference, slug, "artwork")
  end

  @doc """
  Stage 5: Import artworks from festival.art.

  festival.art → Artwork
  - title → title
  - show → visible
  - leader → fields["leader"]
  - description → description
  - photo S3 URL → fields["import_photo_url"] (media download deferred to stage 7)
  - project FK → date (via biennale year), type (inferred from project slug)
  - artist FK → artwork_participant relationship (role: "creator")

  Also creates artwork_event relationships from art.project FK.
  """
  def stage5 do
    arts = records_by_model("festival.art")
    IO.puts("Stage 5: Importing #{length(arts)} artworks...")

    artist_pk_to_id = build_artist_pk_to_participant_id()
    fest_to_biennale = build_festival_pk_to_biennale_id()
    proj_pk_to_event_id = build_project_pk_to_event_id(fest_to_biennale)

    results =
      for art <- arts do
        pk = art["pk"]
        fields = art["fields"]

        existing = find_existing_by_type("festival.art", pk, "artwork")

        if existing do
          {:skipped, existing}
        else
          artist_pk = get_in(art["foreign_keys"], ["artist", "pk"])
          project_pk = get_in(art["foreign_keys"], ["project", "pk"])

          proj_slug = get_project_slug_for_art(project_pk)

          date = get_date_for_art(project_pk, fest_to_biennale)
          art_type = infer_art_type(proj_slug)

          attrs = %{
            title: fields["title"] || "Untitled",
            description: clean_string(fields["description"]),
            type: art_type,
            date: date,
            visible: fields["show"] != false
          }

          case Content.create_artwork(attrs) do
            {:ok, artwork} ->
              leader = fields["leader"] == true

              updated_fields =
                artwork.fields
                |> Map.put("original_record", art)
                |> Map.put("import_pk", to_string(pk))
                |> Map.put("import_model", "festival.art")
                |> Map.put("import_slug", fields["slug"])
                |> Map.put("leader", leader)
                |> Map.put("import_photo_url", fields["photo"])
                |> Map.put("import_text", fields["text"])

              artwork
              |> Ecto.Changeset.change(fields: updated_fields)
              |> Repo.update!()

              maybe_attach_artist(artwork, artist_pk, artist_pk_to_id)
              maybe_attach_event(artwork, project_pk, proj_pk_to_event_id)

              IO.puts("  Created artwork: #{fields["title"]} (PK #{pk}, ID #{artwork.id})")
              {:created, artwork}

            {:error, changeset} ->
              IO.puts("  ERROR creating art PK #{pk}: #{inspect(changeset.errors)}")
              {:error, changeset}
          end
        end
      end

    created = Enum.count(results, &match?({:created, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("\nStage 5 complete: #{created} created, #{skipped} skipped, #{errors} errors")

    :ok
  end

  defp get_project_slug_for_art(project_pk) do
    records = load_records()
    projects = Enum.filter(records, &(&1["model"] == "festival.project"))

    case Enum.find(projects, &(&1["pk"] == project_pk)) do
      nil -> nil
      proj -> normalize_slug(proj["fields"]["slug"])
    end
  end

  defp get_date_for_art(project_pk, fest_to_biennale) do
    records = load_records()
    projects = Enum.filter(records, &(&1["model"] == "festival.project"))

    case Enum.find(projects, &(&1["pk"] == project_pk)) do
      nil ->
        nil

      proj ->
        fest_pk = get_in(proj["foreign_keys"], ["festival", "pk"])
        biennale_id = Map.get(fest_to_biennale, fest_pk)

        if biennale_id do
          biennale = Content.get_biennale!(biennale_id)
          to_string(biennale.fields["year"])
        else
          nil
        end
    end
  end

  defp maybe_attach_artist(_artwork, nil, _), do: nil

  defp maybe_attach_artist(artwork, artist_pk, artist_pk_to_id) do
    case Map.get(artist_pk_to_id, artist_pk) do
      nil ->
        IO.puts("    WARNING: No participant found for artist PK #{artist_pk}")

      participant_id ->
        participant = Content.get_participant!(participant_id)
        Content.attach_participant_to_artwork(artwork, participant, "creator")
    end
  end

  defp maybe_attach_event(_artwork, nil, _), do: nil

  defp maybe_attach_event(artwork, project_pk, proj_pk_to_event_id) do
    case Map.get(proj_pk_to_event_id, project_pk) do
      nil ->
        IO.puts("    WARNING: No event found for project PK #{project_pk}")

      event_id ->
        event = Content.get_event!(event_id)
        Content.attach_event_to_artwork(artwork, event)
    end
  end

  @s3_base "https://s3.amazonaws.com/com.mykonosbiennale.static/"

  defp download_s3_image(url) do
    filename =
      url
      |> String.split("/")
      |> List.last()
      |> URI.decode()

    local_filename = "#{Ecto.UUID.generate()}#{Path.extname(filename)}"
    local_path = MykonosBiennale.Uploads.uploads_path(local_filename)

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        MykonosBiennale.Uploads.ensure_uploads_dir()
        File.write!(local_path, body)
        {:ok, local_filename}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Stage 7: Download S3 images and create Media records.

  Two passes:
  1. Participant headshots (242) — from original_record.fields.headshot
  2. Artwork photos (537) — from fields.import_photo_url

  For each image: download → create Media (source_type: "upload") → attach to entity.
  Skips if media already attached (idempotent).
  """
  def stage7 do
    IO.puts("Stage 7: Importing media from S3...")

    participant_count = import_participant_headshots()
    artwork_count = import_artwork_photos()

    IO.puts("\nStage 7 complete: #{participant_count} headshots, #{artwork_count} artwork photos")

    :ok
  end

  @doc """
  Stage 7a: Import participant headshots only.
  """
  def stage7a do
    IO.puts("Stage 7a: Importing participant headshots...")
    count = import_participant_headshots()
    IO.puts("\nStage 7a complete: #{count} headshots imported")
    :ok
  end

  @doc """
  Stage 7b: Import artwork photos only.
  """
  def stage7b do
    IO.puts("Stage 7b: Importing artwork photos...")
    count = import_artwork_photos()
    IO.puts("\nStage 7b complete: #{count} artwork photos imported")
    :ok
  end

  defp import_participant_headshots do
    participants =
      Repo.all(
        from e in Entity,
          where:
            e.type == "participant" and
              fragment(
                "? ->> 'original_record' IS NOT NULL AND (? ->> 'original_record')::jsonb ->> 'fields' IS NOT NULL AND ((? ->> 'original_record')::jsonb -> 'fields')::jsonb ->> 'headshot' IS NOT NULL AND ((? ->> 'original_record')::jsonb -> 'fields')::jsonb ->> 'headshot' != ''",
                e.fields,
                e.fields,
                e.fields,
                e.fields
              )
      )

    IO.puts("  Downloading #{length(participants)} participant headshots...")

    count =
      for participant <- Enum.with_index(participants) do
        {participant, idx} = participant

        if rem(idx, 50) == 0 and idx > 0 do
          IO.puts("    ...#{idx}/#{length(participants)} headshots processed")
        end

        headshot = get_in(participant.fields, ["original_record", "fields", "headshot"]) || ""

        if headshot == "" do
          0
        else
          case already_has_media?(participant) do
            true ->
              0

            false ->
              url =
                if String.starts_with?(headshot, "http"), do: headshot, else: @s3_base <> headshot

              case download_and_create_media(
                     url,
                     participant.fields["name"] || "Headshot",
                     participant
                   ) do
                {:ok, _} ->
                  1

                {:error, reason} ->
                  IO.puts("    ERROR headshot for #{participant.fields["name"]}: #{reason}")
                  0
              end
          end
        end
      end

    Enum.sum(count)
  end

  defp import_artwork_photos do
    artworks =
      Repo.all(
        from e in Entity,
          where:
            e.type == "artwork" and
              fragment(
                "? ->> 'import_photo_url' IS NOT NULL AND ? ->> 'import_photo_url' != ''",
                e.fields,
                e.fields
              )
      )

    IO.puts("  Downloading #{length(artworks)} artwork photos...")

    count =
      for artwork <- Enum.with_index(artworks) do
        {artwork, idx} = artwork

        if rem(idx, 100) == 0 and idx > 0 do
          IO.puts("    ...#{idx}/#{length(artworks)} artwork photos processed")
        end

        photo_url = artwork.fields["import_photo_url"] || ""

        if photo_url == "" do
          0
        else
          case already_has_media?(artwork) do
            true ->
              0

            false ->
              url =
                if String.starts_with?(photo_url, "http"),
                  do: photo_url,
                  else: @s3_base <> photo_url

              caption = artwork.fields["title"] || "Artwork photo"

              case download_and_create_media(url, caption, artwork) do
                {:ok, _} ->
                  1

                {:error, reason} ->
                  IO.puts("    ERROR photo for artwork ID #{artwork.id}: #{reason}")
                  0
              end
          end
        end
      end

    Enum.sum(count)
  end

  defp already_has_media?(entity) do
    Repo.one(
      from em in MykonosBiennale.Content.EntityMedia,
        where: em.entity_id == ^entity.id,
        limit: 1,
        select: 1
    ) != nil
  end

  defp download_and_create_media(url, caption, entity) do
    case download_s3_image(url) do
      {:ok, local_filename} ->
        case Content.create_media(%{
               source_type: "upload",
               source_path: local_filename,
               caption: caption,
               metadata: %{"imported_from" => url}
             }) do
          {:ok, media} ->
            Content.attach_media_to_entity(entity, media)
            {:ok, media}

          {:error, changeset} ->
            {:error, inspect(changeset.errors)}
        end

      {:error, reason} ->
        {:error, "Download failed: #{reason}"}
    end
  end
end
