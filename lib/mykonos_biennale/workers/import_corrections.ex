defmodule MykonosBiennale.Workers.ImportCorrections do
  @moduledoc """
  Applies corrections from correction.md to participant entities and relationships.

  Reads the markdown table, parses each row, and:
  - For `delete` action: deletes the relationship, and the participant if orphaned
  - For `new` id: creates a new participant and relationship
  - For existing ids: updates the entity fields and relationship roles
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Content.RelationshipType
  alias MykonosBiennale.Repo

  @corrections_path "correction.md"

  def apply(path \\ nil) do
    corrections = load_corrections(path)

    deletes = Enum.filter(corrections, &(&1.action == "delete"))
    news = Enum.filter(corrections, &(&1.id == :new))
    fixes = Enum.filter(corrections, &(&1.action != "delete" and &1.id != :new))

    IO.puts(
      "Applying corrections: #{length(deletes)} deletes, #{length(news)} new, #{length(fixes)} fixes..."
    )

    delete_count = apply_deletes(deletes)
    new_count = apply_news(news)
    fix_count = apply_fixes(fixes)

    IO.puts(
      "\nCorrections complete: #{delete_count} deleted, #{new_count} created, #{fix_count} updated"
    )

    :ok
  end

  defp load_corrections(nil), do: load_corrections(@corrections_path)

  defp load_corrections(path) when is_binary(path) do
    full_path = Path.join(File.cwd!(), path)

    if File.exists?(full_path) do
      {:ok, raw} = File.read(full_path)
      parse_corrections(raw)
    else
      raise "Corrections file not found at #{full_path}"
    end
  end

  defp parse_corrections(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&parse_row/1)
  end

  defp parse_row(line) do
    line = String.trim(line)

    cond do
      not String.starts_with?(line, "|") ->
        []

      String.contains?(line, "---") ->
        []

      true ->
        line
        |> String.trim("|")
        |> String.split("|")
        |> Enum.map(&String.trim/1)
        |> parse_cols()
    end
  end

  defp parse_cols(["id" | _]), do: []

  defp parse_cols([id, film_id, name, first_name, last_name, relationship, roles, action]) do
    [
      build_row(
        id,
        film_id,
        name,
        first_name,
        last_name,
        relationship,
        roles,
        String.trim(action || "")
      )
    ]
  end

  defp parse_cols([id, film_id, name, first_name, last_name, relationship, roles]) do
    [build_row(id, film_id, name, first_name, last_name, relationship, roles, "")]
  end

  defp parse_cols(_), do: []

  defp build_row(id, film_id, name, first_name, last_name, relationship, roles, action) do
    %{
      id: parse_id(id),
      film_id: parse_id(film_id),
      name: name,
      first_name: first_name,
      last_name: last_name,
      relationship: relationship,
      roles: roles,
      action: action
    }
  end

  defp parse_id("new"), do: :new
  defp parse_id(s) when is_binary(s), do: String.to_integer(String.trim(s))

  defp apply_deletes(deletes) do
    for corr <- deletes, reduce: 0 do
      count -> apply_delete(corr, Repo.get(Entity, corr.id), count)
    end
  end

  defp apply_delete(_corr, nil, count), do: count

  defp apply_delete(corr, entity, count) do
    film_id = corr.film_id
    rt = Repo.get_by(RelationshipType, slug: corr.relationship)

    for rel <- relationships_to_delete(rt, entity, film_id) do
      Repo.delete(rel)
    end

    if count_relationships(entity) == 0 do
      Repo.delete(entity)
      IO.puts("  Deleted participant #{corr.id} (#{corr.name}) and all relationships")
    else
      IO.puts(
        "  Deleted relationship #{corr.relationship} for participant #{corr.id} → film #{film_id}"
      )
    end

    count + 1
  end

  defp relationships_to_delete(nil, _entity, _film_id), do: []

  defp relationships_to_delete(rt, entity, film_id) do
    Repo.all(
      from r in Relationship,
        where:
          r.object_id == ^entity.id and r.subject_id == ^film_id and
            r.relationship_type_id == ^rt.id
    )
  end

  defp count_relationships(entity) do
    Repo.one(
      from r in Relationship,
        where: r.object_id == ^entity.id,
        select: count(r.id)
    )
  end

  defp apply_news(news) do
    for corr <- news, reduce: 0 do
      count -> apply_new(corr, Repo.get(Entity, corr.film_id), count)
    end
  end

  defp apply_new(corr, nil, count) do
    IO.puts("  SKIP new #{corr.name}: film #{corr.film_id} not found")
    count
  end

  defp apply_new(corr, film_entity, count) do
    rt = Content.ensure_relationship_type!(corr.relationship, corr.relationship)
    canonical = canonical_name(corr.name)
    participant = find_or_create_participant(corr, canonical)

    if participant do
      upsert_new_relationship(film_entity, participant, rt, corr)

      IO.puts(
        "  Created new: #{corr.name} → film #{corr.film_id} (#{corr.relationship}: #{corr.roles})"
      )

      count + 1
    else
      count
    end
  end

  defp find_or_create_participant(corr, canonical) do
    existing =
      Repo.one(
        from e in Entity,
          where:
            e.type == "participant" and
              fragment("? ->> 'import_name'", e.fields) == ^canonical,
          limit: 1
      )

    existing || create_new_participant(corr, canonical)
  end

  defp create_new_participant(corr, canonical) do
    case Content.create_participant(%{
           first_name: corr.first_name,
           last_name: corr.last_name,
           name: String.trim(corr.name),
           visible: true
         }) do
      {:ok, p} ->
        updated_fields =
          p.fields
          |> Map.put("import_model", "filmfestival.credit")
          |> Map.put("import_name", canonical)
          |> Map.put("import_film_pks", [to_string(corr.film_id)])

        p
        |> Ecto.Changeset.change(fields: updated_fields)
        |> Repo.update!()

        p

      {:error, cs} ->
        IO.puts("  ERROR creating #{corr.name}: #{inspect(cs.errors)}")
        nil
    end
  end

  defp upsert_new_relationship(film_entity, participant, rt, corr) do
    existing_rel =
      Repo.one(
        from r in Relationship,
          where:
            r.subject_id == ^film_entity.id and
              r.object_id == ^participant.id and
              r.relationship_type_id == ^rt.id
      )

    if existing_rel do
      updated_fields = Map.put(existing_rel.fields, "roles", corr.roles)
      existing_rel |> Ecto.Changeset.change(fields: updated_fields) |> Repo.update!()
    else
      Content.create_relationship(%{
        slug: corr.relationship,
        label: corr.relationship,
        subject_id: film_entity.id,
        object_id: participant.id,
        fields: %{"roles" => corr.roles}
      })
    end
  end

  defp apply_fixes(fixes) do
    by_entity = Enum.group_by(fixes, & &1.id)

    for {_id, corrs} <- by_entity, reduce: 0 do
      count -> apply_fix(corrs, Repo.get(Entity, corrs |> hd() |> Map.get(:id)), count)
    end
  end

  defp apply_fix(_corrs, nil, count), do: count

  defp apply_fix(corrs, entity, count) do
    first = hd(corrs)
    name = String.trim(first.name)
    first_name = String.trim(first.first_name)
    last_name = String.trim(first.last_name)

    updated_fields =
      entity.fields
      |> Map.put("name", name)
      |> Map.put("first_name", first_name)
      |> Map.put("last_name", last_name)
      |> Map.put("import_name", canonical_name(name))

    entity
    |> Ecto.Changeset.change(fields: updated_fields, identity: name)
    |> Repo.update!()

    for corr <- corrs do
      fix_relationship(Repo.get_by(RelationshipType, slug: corr.relationship), corr, entity)
    end

    IO.puts("  Fixed: #{name} (ID #{entity.id})")

    count + 1
  end

  defp fix_relationship(nil, _corr, _entity), do: :ok

  defp fix_relationship(rt, corr, entity) do
    rel =
      Repo.one(
        from r in Relationship,
          where:
            r.subject_id == ^corr.film_id and
              r.object_id == ^entity.id and
              r.relationship_type_id == ^rt.id
      )

    if rel do
      updated_rel_fields = Map.put(rel.fields, "roles", String.trim(corr.roles))
      rel |> Ecto.Changeset.change(fields: updated_rel_fields) |> Repo.update!()
    end

    :ok
  end

  defp canonical_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end
end
