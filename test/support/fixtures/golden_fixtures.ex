defmodule MykonosBiennale.GoldenFixtures do
  @moduledoc """
  Loads "golden records" exported from the production/dev database into the
  test sandbox. The dataset (test/support/fixtures/golden/golden.json) contains
  real entity shapes for the key public screens:

    * biennale 2025 (id 7, template "festival-2025") — `/biennale/2025`
    * exhibition event (id 2956) — `/event/2956`
    * screening event (id 64) — `/event/64`
    * artwork (id 3363) — `/art/3363`
    * artist/participant (id 98) — `/artist/98`

  plus their 1-hop related entities, relationships, relationship types, and
  media metadata. Emails/phones are scrubbed. Media `source_path` values are
  rewritten to the bundled `test.jpg` so image handling works without the
  original uploads.

  Usage in tests:

      setup do
        golden = MykonosBiennale.GoldenFixtures.load_golden_data!()
        %{golden: golden}
      end

  Original database IDs are preserved, so routes like `~p"/art/3363"` work
  as-is. `load_golden_data!/0` returns the core ids map.
  """

  alias MykonosBiennale.Repo

  @golden_path Path.expand("golden/golden.json", __DIR__)
  @test_image Path.expand("files/test.jpg", __DIR__)

  @core %{
    biennale: 7,
    screening_event: 64,
    artist: 98,
    exhibition_event: 2956,
    artwork: 3363
  }

  def core_ids, do: @core

  def load_golden_data! do
    data = @golden_path |> File.read!() |> Jason.decode!()
    now = NaiveDateTime.utc_now(:second)

    # Relationship types may already be seeded (by migrations or other
    # fixtures), so upsert by slug and remap ids in relationships.
    rt_id_map =
      Map.new(data["relationship_types"], fn %{"id" => old_id, "slug" => slug, "label" => label} ->
        rt = MykonosBiennale.Content.ensure_relationship_type!(slug, label)
        {old_id, rt.id}
      end)

    entities =
      Enum.map(data["entities"], fn e ->
        Map.update!(e, "fields", &Jason.encode!/1)
      end)

    insert_all!("entities", entities, now)

    relationships =
      Enum.map(data["relationships"], fn r ->
        r
        |> Map.update!("relationship_type_id", &Map.fetch!(rt_id_map, &1))
        |> Map.update("fields", nil, fn
          nil -> nil
          fields -> Jason.encode!(fields)
        end)
      end)

    insert_all!("relationships", relationships, now)

    media =
      Enum.map(data["media"], fn m ->
        m
        |> Map.put("source_path", copy_test_image!(m["source_path"]))
        |> Map.put("mime_type", "image/jpeg")
        |> Map.update("metadata", nil, &encode_json/1)
      end)

    insert_all!("media", media, now)

    entity_media =
      Enum.map(data["entity_media"], fn em ->
        Map.update(em, "metadata", nil, &encode_json/1)
      end)

    insert_all!("entity_media", entity_media, now)

    bump_sequences!()

    @core
  end

  defp encode_json(nil), do: nil
  defp encode_json(map), do: Jason.encode!(map)

  # Copies test.jpg into the media upload dir under a .jpg name derived
  # from the original path, so thumbnailing/serving works in tests.
  defp copy_test_image!(original_path) do
    name = Path.rootname(Path.basename(original_path)) <> ".jpg"
    dir = MykonosBiennale.Uploads.uploads_dir()
    File.mkdir_p!(dir)
    File.cp!(@test_image, Path.join(dir, name))
    name
  rescue
    _ -> Path.rootname(Path.basename(original_path)) <> ".jpg"
  end

  defp insert_all!(table, rows, now) do
    rows =
      Enum.map(rows, fn row ->
        row
        |> Map.new(fn {k, v} -> {String.to_atom(k), decode_value(v)} end)
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    rows
    |> Enum.chunk_every(500)
    |> Enum.each(&Repo.insert_all(table, &1, on_conflict: :nothing))
  end

  defp decode_value(v) when is_binary(v) do
    case Jason.decode(v) do
      {:ok, decoded} when is_map(decoded) or is_list(decoded) -> decoded
      _ -> v
    end
  end

  defp decode_value(v), do: v

  # After inserting rows with explicit IDs, advance the sequences so
  # subsequent fixture inserts do not collide.
  defp bump_sequences! do
    for table <- ~w(entities relationships relationship_types media entity_media) do
      Repo.query!(
        "SELECT setval(pg_get_serial_sequence($1, 'id'), (SELECT COALESCE(MAX(id), 1) FROM #{table}))",
        [table]
      )
    end

    :ok
  end
end
