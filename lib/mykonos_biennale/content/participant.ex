defmodule MykonosBiennale.Content.Participant do
  @moduledoc """
  Participant-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Content.RelationshipType
  alias MykonosBiennale.Repo

  @doc """
  Returns the list of participants ordered by last name.
  """
  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "participant",
        order_by: [asc: fragment("? ->> ?", e.fields, "last_name")]
    )
  end

  @doc """
  Gets a single participant entity by ID.
  """
  def get!(id), do: Repo.get!(Entity, id)

  @doc """
  Creates a participant entity.
  """
  def create(attrs \\ %{}) do
    first_name = attr(attrs, :first_name) || ""
    last_name = attr(attrs, :last_name) || ""
    name = attr(attrs, :name) || "#{first_name} #{last_name}"

    fields = %{
      "first_name" => first_name,
      "last_name" => last_name,
      "name" => name,
      "country" => attr(attrs, :country),
      "email" => attr(attrs, :email),
      "phone" => attr(attrs, :phone),
      "website" => attr(attrs, :website),
      "social_media" => attr(attrs, :social_media) || [],
      "bio" => attr(attrs, :bio),
      "statement" => attr(attrs, :statement)
    }

    slug = Content.slugify("#{first_name}-#{last_name}") <> "-#{System.monotonic_time()}"

    Content.create_entity(%{
      identity: name,
      type: "participant",
      slug: slug,
      visible: Map.get(attrs, :visible, true),
      fields: fields
    })
  end

  @doc """
  Finds an existing participant by name (identity), or creates one if not found.
  """
  def find_or_create_by_name(name) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      nil
    else
      case Repo.one(
             from e in Entity,
               where: e.type == "participant" and e.identity == ^name,
               limit: 1
           ) do
        %Entity{} = existing ->
          {:ok, existing}

        nil ->
          create(%{"name" => name})
      end
    end
  end

  def find_or_create_by_name(_), do: nil

  @doc """
  Updates a participant entity.
  """
  def update(%Entity{} = participant_entity, attrs) do
    current_fields = participant_entity.fields

    update_keys = [
      :first_name,
      :last_name,
      :name,
      :country,
      :email,
      :phone,
      :website,
      :social_media,
      :bio,
      :statement
    ]

    new_fields =
      Enum.reduce(update_keys, current_fields, fn key, acc ->
        case Map.get(attrs, key) do
          nil -> acc
          value -> Map.put(acc, to_string(key), value)
        end
      end)

    name = Map.get(attrs, :name) || new_fields["name"]

    Content.update_entity(participant_entity, %{
      identity: name,
      visible: Map.get(attrs, :visible, participant_entity.visible),
      fields: new_fields
    })
  end

  @doc """
  Deletes a participant entity.
  """
  def delete(%Entity{} = participant_entity) do
    Repo.delete_all(from r in Relationship, where: r.subject_id == ^participant_entity.id)
    Repo.delete_all(from r in Relationship, where: r.object_id == ^participant_entity.id)
    Content.delete_entity(participant_entity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking participant entity changes.
  """
  def change(%Entity{} = participant_entity, attrs \\ %{}) do
    entity_attrs = %{
      identity: Map.get(attrs, :name),
      visible: Map.get(attrs, :visible),
      fields:
        Map.take(attrs, [
          :first_name,
          :last_name,
          :name,
          :country,
          :email,
          :phone,
          :website,
          :social_media,
          :bio,
          :statement
        ])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }

    Entity.changeset(participant_entity, entity_attrs)
  end

  @doc """
  Returns the relationships linking a participant to their artworks.
  Each relationship has the artwork preloaded as `:subject`.
  """
  def list_linked_artworks(%Entity{} = participant) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^participant.id and r.relationship_type_id == ^rt.id,
          preload: [:subject, :relationship_type]
      )
    else
      []
    end
  end

  @film_rel_slugs ~w(directed produced screenwrote acted_in composed_for shot edited exec_produced participated_in)

  @doc """
  Returns all works (artworks + films) for a participant, grouped by biennale.

  Each group is `%{biennale: Entity | nil, year: integer | nil, works: [work]}`.
  Each work is `%{entity: Entity, type: String, roles: [String], media: [Media], events: [Entity]}`.
  Works are deduplicated by entity ID — if a participant has multiple relationships
  to the same film (e.g. directed + edited), they appear once with all roles listed.
  Works with no biennale are in a group with `biennale: nil`.
  Groups are sorted by year descending.
  """
  def list_works_by_biennale(%Entity{} = participant) do
    works = load_all_works(participant)
    biennale_map = build_biennale_map(works)
    groups = group_works_by_biennale(works, biennale_map)
    sort_groups(groups)
  end

  defp load_all_works(participant) do
    artwork_works = load_artwork_works(participant)
    film_works = load_film_works(participant)

    (artwork_works ++ film_works)
    |> Enum.reject(&is_nil(&1.entity))
    |> Enum.group_by(& &1.entity.id)
    |> Enum.map(fn {_id, group} ->
      first = List.first(group)

      %{
        entity: first.entity,
        type: first.type,
        roles: Enum.uniq(Enum.map(group, & &1.role)),
        media: first.media,
        events: first.events
      }
    end)
  end

  defp load_artwork_works(participant) do
    rels = list_linked_artworks(participant)

    Enum.map(rels, fn rel ->
      artwork = rel.subject

      if artwork && artwork.visible do
        %{
          entity: artwork,
          type: artwork.type,
          role: get_in(rel.fields, ["role"]) || "artist",
          media: Content.list_media_for_entity(artwork),
          events: load_work_events(artwork, "artwork_event")
        }
      else
        %{entity: nil, type: nil, role: nil, media: [], events: []}
      end
    end)
  end

  defp load_film_works(participant) do
    rt_ids =
      Repo.all(from rt in RelationshipType, where: rt.slug in ^@film_rel_slugs, select: rt.id)

    case rt_ids do
      [] ->
        []

      _ ->
        Repo.all(
          from r in Relationship,
            where: r.object_id == ^participant.id and r.relationship_type_id in ^rt_ids,
            preload: [:subject, :relationship_type]
        )
        |> Enum.map(&film_work/1)
    end
  end

  defp film_work(rel) do
    film = rel.subject

    if film && film.visible do
      %{
        entity: film,
        type: film.type,
        role: rel.relationship_type.label,
        media: Content.list_media_for_entity(film),
        events: load_work_events(film, "screened_at")
      }
    else
      %{entity: nil, type: nil, role: nil, media: [], events: []}
    end
  end

  defp load_work_events(work, slug) do
    rt = Repo.get_by(RelationshipType, slug: slug)

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^work.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
      |> Enum.map(& &1.object)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp build_biennale_map(works) do
    all_event_ids =
      works
      |> Enum.flat_map(& &1.events)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    if all_event_ids == [] do
      %{}
    else
      event_biennale_map(all_event_ids)
    end
  end

  defp event_biennale_map(event_ids) do
    case Repo.get_by(RelationshipType, slug: "biennale_event") do
      nil ->
        %{}

      be_rt ->
        rels =
          Repo.all(
            from r in Relationship,
              where: r.subject_id in ^event_ids and r.relationship_type_id == ^be_rt.id,
              preload: [:object]
          )

        Enum.into(rels, %{}, fn rel -> {rel.subject_id, rel.object} end)
    end
  end

  defp attr(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, to_string(key))

  defp group_works_by_biennale(works, biennale_map) do
    works_with_biennale =
      Enum.map(works, fn work ->
        biennale =
          work.events
          |> Enum.find_value(fn event -> Map.get(biennale_map, event.id) end)

        year =
          if biennale && biennale.fields["year"],
            do: parse_year(biennale.fields["year"]),
            else: nil

        {work, biennale, year}
      end)

    grouped =
      Enum.group_by(works_with_biennale, fn {_, _biennale, year} ->
        year
      end)

    Enum.map(grouped, fn {year, items} ->
      biennale = items |> List.first() |> elem(1)
      works = Enum.map(items, fn {work, _, _} -> work end)
      %{biennale: biennale, year: year, works: works}
    end)
  end

  defp sort_groups(groups) do
    Enum.sort_by(groups, fn %{year: year} -> year || 0 end, :desc)
  end

  defp parse_year(y) when is_integer(y), do: y

  defp parse_year(y) when is_binary(y) do
    case Integer.parse(y) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_year(_), do: nil

  @doc """
  Detaches an artwork from a participant by removing the
  `artwork_participant` relationship between them.
  """
  def detach_artwork(%Entity{} = participant, artwork_id) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      case Repo.get_by(Relationship,
             object_id: participant.id,
             relationship_type_id: rt.id,
             subject_id: artwork_id
           ) do
        %Relationship{} = rel -> Content.delete_relationship(rel)
        nil -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end
end
