defmodule MykonosBiennale.Workers.ImportFilmfestival do
  @moduledoc """
  Imports film festival data from exports/filmfestival/records.json into the new schema.

  Assumes Workers.ImportFestival.stage1..stage7 has already run, populating
  biennales, projects, events.

  Run stages sequentially via iex:
    iex> ImportFilmfestival.stage1()
    iex> ImportFilmfestival.stage2()
    ...
    iex> ImportFilmfestival.run_all()
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}

  @records_path "exports/filmfestival/records.json"

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

  defp selected_films do
    records_by_model("filmfestival.film")
    |> Enum.filter(&(&1["fields"]["status"] == "SELECTED"))
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

  defp find_existing_film(pk) do
    pk_str = to_string(pk)

    Repo.one(
      from(e in Entity,
        where:
          fragment("? ->> 'import_model'", e.fields) == "filmfestival.film" and
            fragment("? ->> 'import_pk'", e.fields) == ^pk_str
      )
    )
  end

  defp find_participant_by_canonical_name(canonical) do
    Repo.one(
      from(e in Entity,
        where:
          e.type == "participant" and
            fragment("? ->> 'import_model'", e.fields) == "filmfestival.credit" and
            fragment("? ->> 'import_name'", e.fields) == ^canonical
      )
    )
  end

  @film_type_mapping %{
    "Dramatic Nights" => "Short Film",
    "Video Grafitti" => "Video",
    "Video Graffiti" => "Video",
    "Dance" => "Dance",
    "Animation" => "Animation",
    "Documentary" => "Documentary"
  }

  defp film_type_to_entity_type(film_type) do
    Map.get(@film_type_mapping, film_type, "Short Film")
  end

  @film_field_keys ~w(year runtime country language synopsis synopsis_125 synopsis_250 log_line production_notes directors_statement dir_by sub_by genres niches ref url trailer_url trailer_embed facebook twitter other_social_media original_title subtitles projection_copy projection_copy_url)

  defp clean_string(nil), do: nil
  defp clean_string(""), do: nil
  defp clean_string(s) when is_binary(s), do: String.trim(s)
  defp clean_string(other), do: other

  @rel_types [
    {"screened_at", "screened_at"},
    {"directed", "directed"},
    {"produced", "produced"},
    {"screenwrote", "screenwrote"},
    {"acted_in", "acted_in"},
    {"composed_for", "composed_for"},
    {"shot", "shot"},
    {"edited", "edited"},
    {"exec_produced", "exec_produced"},
    {"participated_in", "participated_in"}
  ]

  @principal_field_to_slug %{
    "directors" => "directed",
    "dir_by" => "directed",
    "producers" => "produced",
    "screenwriters" => "screenwrote",
    "actors" => "acted_in",
    "composers" => "composed_for",
    "cinematographers" => "shot",
    "editors" => "edited",
    "exec_producers" => "exec_produced"
  }

  @secondary_field_to_role %{
    "co_producers" => "Co-Producer",
    "sound_editors" => "Sound Editor",
    "product_designers" => "Production Designer",
    "art_directors" => "Art Director",
    "crew" => "Crew"
  }

  @principal_field_default_role %{
    "directors" => "Director",
    "dir_by" => "Director",
    "producers" => "Producer",
    "screenwriters" => "Screenwriter",
    "actors" => "Actor",
    "composers" => "Composer",
    "cinematographers" => "Cinematographer",
    "editors" => "Editor",
    "exec_producers" => "Executive Producer"
  }

  @doc """
  Stage 1: Ensure relationship types exist (idempotent).
  """
  def stage1 do
    IO.puts("Stage 1: Ensuring #{length(@rel_types)} relationship types...")

    Enum.each(@rel_types, fn {slug, label} ->
      Content.ensure_relationship_type!(slug, label)
      IO.puts("  OK: #{slug}")
    end)

    IO.puts("\nStage 1 complete")
    :ok
  end

  @doc """
  Stage 2: Import selected films as entities (~347).
  """
  def stage2 do
    films = selected_films()
    IO.puts("Stage 2: Importing #{length(films)} selected films...")

    results =
      for film <- films do
        pk = film["pk"]
        fields = film["fields"]
        title = String.trim(fields["title"] || "Untitled")
        entity_type = film_type_to_entity_type(fields["film_type"])

        existing = find_existing_film(pk)

        if existing do
          IO.puts("  Skipping film PK #{pk} (already ID #{existing.id})")
          {:skipped, existing}
        else
          film_fields =
            @film_field_keys
            |> Enum.reduce(%{}, fn key, acc ->
              val = fields[key]
              if val != nil and val != "", do: Map.put(acc, key, val), else: acc
            end)

          attrs = %{
            identity: title,
            type: entity_type,
            slug: Content.slugify(title) <> "-#{System.monotonic_time()}",
            visible: true,
            fields: film_fields
          }

          case Content.create_entity(attrs) do
            {:ok, entity} ->
              updated_fields =
                entity.fields
                |> Map.put("original_record", film)
                |> Map.put("import_pk", to_string(pk))
                |> Map.put("import_model", "filmfestival.film")
                |> Map.put("import_slug", fields["slug"])
                |> Map.put("import_poster_url", clean_string(fields["poster"]))

              entity
              |> Ecto.Changeset.change(fields: updated_fields)
              |> Repo.update!()

              IO.puts("  Created #{entity_type}: #{title} (PK #{pk}, ID #{entity.id})")
              {:created, entity}

            {:error, changeset} ->
              IO.puts("  ERROR film PK #{pk} (#{title}): #{inspect(changeset.errors)}")
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

  @doc """
  Stage 3: Create film → screened_at → event relationships.
  """
  def stage3 do
    films = selected_films()
    project_pk_to_event_id = build_project_pk_to_event_id()
    rt = Repo.get_by!(RelationshipType, slug: "screened_at")

    IO.puts("Stage 3: Creating screened_at relationships for #{length(films)} films...")

    results =
      for film <- films do
        pk = film["pk"]
        project_pk = get_in(film["foreign_keys"], ["project", "pk"])
        event_id = Map.get(project_pk_to_event_id, project_pk)

        film_entity = find_existing_film(pk)

        cond do
          film_entity == nil ->
            IO.puts("  Skipping PK #{pk}: film entity not found")
            {:skipped, :no_entity}

          event_id == nil ->
            IO.puts("  Skipping PK #{pk}: no event for project PK #{project_pk}")
            {:skipped, :no_event}

          true ->
            existing =
              Repo.one(
                from r in Relationship,
                  where:
                    r.subject_id == ^film_entity.id and
                      r.relationship_type_id == ^rt.id and
                      r.object_id == ^event_id
              )

            if existing do
              {:skipped, :exists}
            else
              case Content.create_relationship(%{
                     slug: "screened_at",
                     label: "screened_at",
                     subject_id: film_entity.id,
                     object_id: event_id,
                     fields: %{}
                   }) do
                {:ok, _} ->
                  {:created, pk}

                {:error, cs} ->
                  IO.puts("  ERROR screened_at PK #{pk}: #{inspect(cs.errors)}")
                  {:error, cs}
              end
            end
        end
      end

    created = Enum.count(results, &match?({:created, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _}, &1))
    errors = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("\nStage 3 complete: #{created} created, #{skipped} skipped, #{errors} errors")
    :ok
  end

  @doc """
  Stage 4: Extract participants from credit fields and create participant entities.
  Deduplicates by canonical name.
  """
  def stage4 do
    films = selected_films()
    IO.puts("Stage 4: Extracting participants from #{length(films)} films...")

    name_map = Agent.start_link(fn -> %{} end) |> elem(1)

    credit_fields = Map.keys(@principal_field_to_slug) ++ Map.keys(@secondary_field_to_role)

    results =
      for film <- films, field <- credit_fields, reduce: %{created: 0, skipped: 0, errors: 0} do
        acc ->
          raw = film["fields"][field] || ""
          entries = parse_credit_entries(field, raw)

          for {name, _role} <- entries, reduce: acc do
            acc ->
              canonical = canonical_name(name)
              cached = Agent.get(name_map, &Map.get(&1, canonical))

              cond do
                cached != nil ->
                  %{acc | skipped: acc.skipped + 1}

                find_participant_by_canonical_name(canonical) != nil ->
                  Agent.update(name_map, &Map.put(&1, canonical, :existing))
                  %{acc | skipped: acc.skipped + 1}

                true ->
                  {first_name, last_name} = split_name(name)

                  case Content.create_participant(%{
                         first_name: first_name,
                         last_name: last_name,
                         name: String.trim(name),
                         visible: true
                       }) do
                    {:ok, participant} ->
                      updated_fields =
                        participant.fields
                        |> Map.put("import_model", "filmfestival.credit")
                        |> Map.put("import_name", canonical)
                        |> Map.put("import_film_pks", [to_string(film["pk"])])

                      participant
                      |> Ecto.Changeset.change(fields: updated_fields)
                      |> Repo.update!()

                      Agent.update(name_map, &Map.put(&1, canonical, participant.id))

                      if rem(acc.created, 100) == 0 and acc.created > 0 do
                        IO.puts("    ...#{acc.created} participants created so far")
                      end

                      %{acc | created: acc.created + 1}

                    {:error, cs} ->
                      IO.puts("  ERROR participant '#{name}': #{inspect(cs.errors)}")
                      %{acc | errors: acc.errors + 1}
                  end
              end
          end
      end

    Agent.stop(name_map)

    IO.puts(
      "\nStage 4 complete: #{results.created} created, #{results.skipped} skipped, #{results.errors} errors"
    )

    :ok
  end

  @doc """
  Stage 5: Create credit relationships (film → participant with role).
  Merges roles into single relationship row per (film, participant, slug) triple.
  """
  def stage5 do
    films = selected_films()
    IO.puts("Stage 5: Creating credit relationships for #{length(films)} films...")

    credit_fields = Map.keys(@principal_field_to_slug) ++ Map.keys(@secondary_field_to_role)

    results =
      for film <- films,
          field <- credit_fields,
          reduce: %{created: 0, updated: 0, skipped: 0, errors: 0} do
        acc ->
          raw = film["fields"][field] || ""
          entries = parse_credit_entries(field, raw)
          film_entity = find_existing_film(film["pk"])

          if film_entity == nil do
            acc
          else
            for {name, role} <- entries, reduce: acc do
              acc ->
                canonical = canonical_name(name)
                participant = find_participant_by_canonical_name(canonical)

                if participant == nil do
                  acc
                else
                  slug = resolve_slug(field)
                  role = role_or_default(field, role)
                  rt = Repo.get_by!(RelationshipType, slug: slug)

                  existing =
                    Repo.one(
                      from r in Relationship,
                        where:
                          r.subject_id == ^film_entity.id and
                            r.object_id == ^participant.id and
                            r.relationship_type_id == ^rt.id
                    )

                  cond do
                    existing == nil ->
                      case Content.create_relationship(%{
                             slug: slug,
                             label: slug,
                             subject_id: film_entity.id,
                             object_id: participant.id,
                             fields: %{"roles" => role}
                           }) do
                        {:ok, _} ->
                          %{acc | created: acc.created + 1}

                        {:error, cs} ->
                          IO.puts("  ERROR rel #{slug} #{name}: #{inspect(cs.errors)}")
                          %{acc | errors: acc.errors + 1}
                      end

                    role_not_in_existing?(existing, role) ->
                      merged = merge_roles(existing.fields["roles"], role)

                      existing
                      |> Ecto.Changeset.change(fields: Map.put(existing.fields, "roles", merged))
                      |> Repo.update!()

                      %{acc | updated: acc.updated + 1}

                    true ->
                      %{acc | skipped: acc.skipped + 1}
                  end
                end
            end
          end
      end

    IO.puts(
      "\nStage 5 complete: #{results.created} created, #{results.updated} updated, #{results.skipped} skipped, #{results.errors} errors"
    )

    :ok
  end

  @doc """
  Stage 6: Download poster + screenshot/still media from S3 and attach to film entities.
  """
  def stage6 do
    films = selected_films()
    IO.puts("Stage 6: Importing media for #{length(films)} films...")

    poster_count = import_posters(films)
    image_count = import_film_images()

    IO.puts("\nStage 6 complete: #{poster_count} posters, #{image_count} screenshots/stills")
    :ok
  end

  defp import_posters(films) do
    total = length(films)
    IO.puts("  Downloading posters (#{total} films)...")

    count =
      for {film, idx} <- Enum.with_index(films, 1), reduce: 0 do
        count ->
          pk = film["pk"]
          poster_url = film["fields"]["poster"] || ""

          if poster_url == "" do
            if rem(idx, 50) == 0, do: IO.puts("  [#{idx}/#{total}] skipping (no poster)...")
            count
          else
            film_entity = find_existing_film(pk)

            if film_entity == nil do
              if rem(idx, 50) == 0,
                do: IO.puts("  [#{idx}/#{total}] skipping (entity not found)...")

              count
            else
              if already_has_media_with_url?(film_entity, poster_url) do
                if rem(idx, 50) == 0,
                  do: IO.puts("  [#{idx}/#{total}] skipping (already imported)...")

                count
              else
                title = String.trim(film["fields"]["title"] || "Film")

                case download_and_create_media(poster_url, "#{title} poster", film_entity, %{
                       "role" => "poster",
                       "is_poster" => true
                     }) do
                  {:ok, _} ->
                    if rem(idx, 25) == 0, do: IO.puts("  [#{idx}/#{total}] poster OK: #{title}")
                    count + 1

                  {:error, reason} ->
                    IO.puts("    [#{idx}/#{total}] ERROR poster PK #{pk}: #{reason}")
                    count
                end
              end
            end
          end
      end

    IO.puts("  #{count} posters downloaded")
    count
  end

  defp import_film_images do
    images = records_by_model("filmfestival.image")

    film_pk_to_entity_id = build_film_pk_to_entity_id()

    selected_film_pks =
      selected_films()
      |> Enum.map(& &1["pk"])
      |> MapSet.new()

    relevant_images =
      Enum.filter(images, fn img ->
        film_pk = get_in(img["foreign_keys"], ["film", "pk"])
        film_pk != nil and MapSet.member?(selected_film_pks, film_pk)
      end)

    IO.puts("  Downloading #{length(relevant_images)} screenshots/stills...")

    total_imgs = length(relevant_images)

    count =
      for {image, idx} <- Enum.with_index(relevant_images, 1), reduce: 0 do
        count ->
          film_pk = get_in(image["foreign_keys"], ["film", "pk"])
          film_entity_id = Map.get(film_pk_to_entity_id, film_pk)

          if film_entity_id == nil do
            count
          else
            film_entity = Repo.get!(Entity, film_entity_id)
            img_url = image["fields"]["image"] || ""
            image_type = image["fields"]["image_type"] || "Screenshot"
            role = String.downcase(image_type)
            title = image["fields"]["title"] || image_type

            if img_url == "" or already_has_media_with_url?(film_entity, img_url) do
              if rem(idx, 50) == 0, do: IO.puts("  [#{idx}/#{total_imgs}] skipping image...")
              count
            else
              case download_and_create_media(img_url, title, film_entity, %{
                     "role" => role,
                     "import_pk" => to_string(image["pk"]),
                     "import_model" => "filmfestival.image"
                   }) do
                {:ok, _} ->
                  if rem(idx, 25) == 0, do: IO.puts("  [#{idx}/#{total_imgs}] image OK: #{title}")
                  count + 1

                {:error, reason} ->
                  IO.puts("    [#{idx}/#{total_imgs}] ERROR image PK #{image["pk"]}: #{reason}")
                  count
              end
            end
          end
      end

    IO.puts("  #{count} screenshots/stills downloaded")
    count
  end

  @doc """
  Convenience: run all stages sequentially.
  """
  def run_all do
    IO.puts("=== Film Festival Migration: Running all stages ===\n")
    stage1()
    stage2()
    stage3()
    stage4()
    stage5()
    stage6()
    IO.puts("\n=== Film Festival Migration: Complete ===")
    :ok
  end

  ## -- Credit parsing helpers --

  defp parse_credit_entries("actors", raw) when is_binary(raw) and raw != "" do
    Regex.scan(~r/(?<name>[^,()]+?)\s*(?:\((?<role>[^()]+)\))?\s*(?:,|$)/m, raw,
      capture: :all_names
    )
    |> Enum.map(fn [n, r] ->
      name = String.trim(n)
      role = if r != "", do: title_case_role(r), else: nil
      {name, role}
    end)
    |> Enum.reject(fn {n, _} -> n == "" end)
  end

  defp parse_credit_entries(field, raw) when is_binary(raw) and raw != "" do
    raw
    |> String.split(~r/\r?\n/)
    |> Enum.flat_map(fn line ->
      line
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.map(fn entry -> extract_name_and_role(entry, field) end)
    |> Enum.reject(fn {n, _} -> n == "" end)
  end

  defp parse_credit_entries(_, _), do: []

  defp extract_name_and_role(entry, _field) do
    entry = String.trim(entry)

    cond do
      Regex.match?(~r/^[^-]+\s+-\s+/, entry) ->
        case Regex.run(~r/^(?<name>[^-]+?)\s+-\s+(?<role>.+)$/, entry) do
          [_, name, role] -> {String.trim(name), title_case_role(role)}
          _ -> {entry, nil}
        end

      Regex.match?(~r/^(?:[A-Z][a-z'\-]+\s+)+(?:[A-Z][A-Z\s]{2,}[A-Z])$/, entry) ->
        case Regex.run(~r/^(?<name>(?:[A-Z][a-z'\-]+\s+)+)(?<role>[A-Z][A-Z\s]{2,}[A-Z])$/, entry) do
          [_, name, role] -> {String.trim(name), title_case_role(role)}
          _ -> {entry, nil}
        end

      true ->
        {entry, nil}
    end
  end

  defp title_case_role(role) when is_binary(role) do
    role
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp canonical_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
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

  defp resolve_slug(field) do
    Map.get(@principal_field_to_slug, field, "participated_in")
  end

  defp role_or_default(field, nil) do
    Map.get(@principal_field_default_role, field) ||
      Map.get(@secondary_field_to_role, field, "Crew")
  end

  defp role_or_default(_field, role), do: role

  defp role_not_in_existing?(%Relationship{fields: fields}, role) do
    existing_roles = fields["roles"] || ""
    existing_list = String.split(existing_roles, ", ") |> Enum.map(&String.trim/1)
    role not in existing_list
  end

  defp merge_roles(existing_roles, new_role) do
    existing_list = String.split(existing_roles || "", ", ") |> Enum.map(&String.trim/1)

    if new_role in existing_list do
      Enum.join(existing_list, ", ")
    else
      Enum.join(existing_list ++ [new_role], ", ")
    end
  end

  ## -- Lookup helpers --

  defp build_project_pk_to_event_id do
    Repo.all(
      from e in Entity,
        where:
          e.type == "event" and
            fragment("? ->> 'import_model'", e.fields) == "festival.project",
        select: {fragment("CAST(? ->> 'import_pk' AS INTEGER)", e.fields), e.id}
    )
    |> Enum.into(%{})
  end

  defp build_film_pk_to_entity_id do
    Repo.all(
      from e in Entity,
        where: fragment("? ->> 'import_model'", e.fields) == "filmfestival.film",
        select: {fragment("CAST(? ->> 'import_pk' AS INTEGER)", e.fields), e.id}
    )
    |> Enum.into(%{})
  end

  ## -- Media helpers --

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

  defp already_has_media_with_url?(entity, url) do
    Repo.one(
      from em in EntityMedia,
        join: m in Media,
        on: m.id == em.media_id,
        where:
          em.entity_id == ^entity.id and fragment("? ->> 'imported_from'", m.metadata) == ^url,
        limit: 1,
        select: 1
    ) != nil
  end

  defp download_and_create_media(url, caption, entity, metadata) do
    case download_s3_image(url) do
      {:ok, local_filename} ->
        case Content.create_media(%{
               source_type: "upload",
               source_path: local_filename,
               caption: caption,
               metadata: Map.put(metadata, "imported_from", url)
             }) do
          {:ok, media} ->
            Content.attach_media_to_entity(entity, media, metadata: metadata)
            {:ok, media}

          {:error, changeset} ->
            {:error, inspect(changeset.errors)}
        end

      {:error, reason} ->
        {:error, "Download failed: #{reason}"}
    end
  end
end
