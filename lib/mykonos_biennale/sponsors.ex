defmodule MykonosBiennale.Sponsors do
  @moduledoc """
  Sponsors and supporters of the biennale.

  A sponsor is an entity of type `sponsor`: `identity` is the name and
  `fields["url"]` is the website. Support for a biennale is a relationship
  `sponsor -> biennale_sponsor -> biennale`. The logo is optional: when present
  it is a media row attached to the sponsor entity with `role: "logo"`.
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.EntityMedia
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Content.RelationshipType
  alias MykonosBiennale.Repo

  @entity_type "sponsor"
  @relationship_slug "biennale_sponsor"
  @logo_role "logo"

  def entity_type, do: @entity_type
  def relationship_slug, do: @relationship_slug

  @doc """
  Returns the `biennale_sponsor` relationship type, creating it if missing.
  """
  def ensure_relationship_type do
    case Repo.get_by(RelationshipType, slug: @relationship_slug) do
      nil ->
        {:ok, relationship_type} =
          RelationshipType.create(%{slug: @relationship_slug, label: "sponsor"})

        relationship_type

      relationship_type ->
        relationship_type
    end
  end

  # -- Reads --

  @doc """
  Lists every sponsor with its logo (or nil) and the biennales it supports,
  newest biennale first.
  """
  def list_sponsors do
    sponsors = Repo.all(from e in Entity, where: e.type == ^@entity_type, order_by: e.identity)
    ids = Enum.map(sponsors, & &1.id)
    supports = Enum.group_by(supports_query(ids), &elem(&1, 0), &elem(&1, 1))
    logos = Map.new(logo_query(ids))

    Enum.map(sponsors, fn sponsor ->
      biennales = Enum.sort_by(Map.get(supports, sponsor.id, []), & &1.year, :desc)

      %{
        id: sponsor.id,
        entity: sponsor,
        name: sponsor.identity,
        url: url_of(sponsor),
        logo: Map.get(logos, sponsor.id),
        biennales: biennales,
        years: Enum.map(biennales, & &1.year)
      }
    end)
  end

  @doc """
  Sponsors that support one biennale, as `%{name, url, media, media_id}` maps
  sorted by name. Used by the public biennale pages and the biennale form.
  """
  def for_biennale(biennale_id) do
    sponsors =
      Repo.all(
        from r in Relationship,
          join: rt in RelationshipType,
          on: rt.id == r.relationship_type_id,
          join: s in Entity,
          on: s.id == r.subject_id,
          where:
            rt.slug == ^@relationship_slug and r.object_id == ^biennale_id and
              s.type == ^@entity_type,
          order_by: s.identity,
          select: s
      )

    logos = sponsors |> Enum.map(& &1.id) |> logo_query() |> Map.new()

    Enum.map(sponsors, fn sponsor ->
      media = Map.get(logos, sponsor.id)

      %{
        id: sponsor.id,
        name: sponsor.identity,
        url: url_of(sponsor),
        media: media,
        media_id: media && media.id
      }
    end)
  end

  # -- Writes --

  @doc """
  Creates or updates a sponsor by name.

  Options:
    * `:sponsor` - the existing sponsor entity to update (rename allowed)
    * `:logo` - a `%Media{}` to use as the logo (replaces the current one)

  Returns `{:ok, entity}` or `{:error, reason}`.
  """
  def save(name, url, opts \\ []) do
    sponsor = Keyword.get(opts, :sponsor)
    logo = Keyword.get(opts, :logo)

    Repo.transaction(fn ->
      entity =
        case resolve_entity(sponsor, name, url) do
          {:ok, entity} -> entity
          {:error, reason} -> Repo.rollback(reason)
        end

      if logo, do: set_logo(entity, logo)
      entity
    end)
  end

  @doc "Links a sponsor to a biennale, if not already linked."
  def link(sponsor_id, biennale_id) do
    relationship_type = ensure_relationship_type()

    if existing_link(sponsor_id, biennale_id, relationship_type.id) do
      :ok
    else
      {:ok, _} =
        Content.create_relationship(%{
          relationship_type_id: relationship_type.id,
          subject_id: sponsor_id,
          object_id: biennale_id
        })

      :ok
    end
  end

  @doc "Removes a sponsor's support for one biennale."
  def unlink(sponsor_id, biennale_id) do
    relationship_type = ensure_relationship_type()

    Repo.delete_all(
      from r in Relationship,
        where:
          r.subject_id == ^sponsor_id and r.object_id == ^biennale_id and
            r.relationship_type_id == ^relationship_type.id
    )

    :ok
  end

  @doc "Deletes a sponsor, its support links and its logo link (the media row stays)."
  def delete(%Entity{id: id} = sponsor) do
    Repo.transaction(fn ->
      Repo.delete_all(from r in Relationship, where: r.subject_id == ^id)
      Repo.delete_all(from em in EntityMedia, where: em.entity_id == ^id)
      Repo.delete!(sponsor)
    end)
  end

  # -- Legacy migration --

  @doc """
  Plans the migration of legacy sponsor links (`entity_media` rows with
  `role: "sponsor"` on biennales) into sponsor entities and relationships.

  Returns one map per distinct sponsor name. Nothing is written.
  """
  def legacy_plan do
    rows =
      Repo.all(
        from em in EntityMedia,
          where: fragment("? ->> 'role'", em.metadata) == "sponsor",
          select: %{entity_id: em.entity_id, media_id: em.media_id, metadata: em.metadata}
      )

    rows
    |> Enum.group_by(fn row -> row.metadata["name"] || "" end)
    |> Enum.map(fn {name, group} ->
      %{
        name: name,
        url: group |> Enum.map(& &1.metadata["url"]) |> Enum.find(&(&1 not in [nil, ""])) || "",
        biennale_ids: group |> Enum.map(& &1.entity_id) |> Enum.uniq(),
        media_id: group |> Enum.map(& &1.media_id) |> Enum.find(& &1)
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Applies a plan from `legacy_plan/0`. Legacy `entity_media` rows are left in
  place, so the migration can be re-run and reviewed before they are removed.
  Plans without a name are skipped.
  """
  def apply_legacy_plan(plan) do
    plan
    |> Enum.reject(&(&1.name == ""))
    |> Enum.each(fn item ->
      logo = item.media_id && Repo.get(Media, item.media_id)
      {:ok, sponsor} = save(item.name, item.url, logo: logo)
      Enum.each(item.biennale_ids, &link(sponsor.id, &1))
    end)

    :ok
  end

  # -- Helpers --

  defp resolve_entity(nil, name, url) do
    case find_by_name(name) do
      nil -> insert_entity(name, url)
      existing -> {:ok, write_fields(existing, name, url)}
    end
  end

  defp resolve_entity(%Entity{id: sponsor_id} = sponsor, name, url) do
    case find_by_name(name) do
      %Entity{id: other_id} when other_id != sponsor_id -> {:error, :name_taken}
      _ -> {:ok, write_fields(sponsor, name, url)}
    end
  end

  defp find_by_name(name) do
    Repo.one(from e in Entity, where: e.type == ^@entity_type and e.identity == ^name, limit: 1)
  end

  defp insert_entity(name, url) do
    Content.create_entity(%{
      identity: name,
      type: @entity_type,
      slug: "sponsor-" <> Content.slugify(name),
      visible: true,
      fields: %{"url" => url}
    })
  end

  defp write_fields(%Entity{} = entity, name, url) do
    fields = Map.put(entity.fields || %{}, "url", url)

    entity
    |> Entity.changeset(%{identity: name, fields: fields})
    |> Repo.update!()
  end

  defp set_logo(%Entity{id: sponsor_id} = sponsor, %Media{} = media) do
    Repo.delete_all(
      from em in EntityMedia,
        where:
          em.entity_id == ^sponsor_id and
            fragment("? ->> 'role'", em.metadata) == ^@logo_role
    )

    Content.attach_media_to_entity(sponsor, media, metadata: %{"role" => @logo_role})
  end

  defp existing_link(sponsor_id, biennale_id, relationship_type_id) do
    Repo.exists?(
      from r in Relationship,
        where:
          r.subject_id == ^sponsor_id and r.object_id == ^biennale_id and
            r.relationship_type_id == ^relationship_type_id
    )
  end

  defp supports_query([]), do: []

  defp supports_query(sponsor_ids) do
    Repo.all(
      from r in Relationship,
        join: rt in RelationshipType,
        on: rt.id == r.relationship_type_id,
        join: b in Entity,
        on: b.id == r.object_id,
        where: rt.slug == ^@relationship_slug and r.subject_id in ^sponsor_ids,
        select: {r.subject_id, %{id: b.id, year: fragment("? ->> 'year'", b.fields)}}
    )
  end

  defp logo_query([]), do: []

  defp logo_query(entity_ids) do
    Repo.all(
      from em in EntityMedia,
        join: m in Media,
        on: m.id == em.media_id,
        where:
          em.entity_id in ^entity_ids and
            fragment("? ->> 'role'", em.metadata) == ^@logo_role,
        select: {em.entity_id, m}
    )
  end

  defp url_of(%Entity{fields: fields}), do: (fields || %{})["url"] || ""
end
