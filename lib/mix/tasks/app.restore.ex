defmodule Mix.Tasks.App.Restore do
  @moduledoc """
  Restores application data from a JSON dump file.

  This will DELETE existing data and replace it with the dump contents.
  Useful for seeding production or syncing local dev with production data.

  Usage:
      mix app.restore                      # restores from priv/repo/data_dump.json
      mix app.restore --input mydata.json # restores from specified file
  """
  use Mix.Task

  alias MykonosBiennale.Repo

  @shortdoc "Restore all data from a JSON dump"

  @table_order ~w(sections pages relationships entity_media media entities users_tokens users relationship_types)

  @columns %{
    relationship_types: ~w(id label slug inserted_at updated_at)a,
    users: ~w(id email hashed_password confirmed_at inserted_at updated_at)a,
    users_tokens: ~w(id token context sent_to authenticated_at user_id inserted_at)a,
    entities: ~w(id identity type slug visible template fields search_index search_indexed_at inserted_at updated_at)a,
    media: ~w(id caption source_type source_url source_embed source_path mime_type alt_text metadata search_index search_indexed_at inserted_at updated_at)a,
    entity_media: ~w(entity_id media_id position metadata inserted_at updated_at)a,
    relationships: ~w(id fields relationship_type_id subject_id object_id inserted_at updated_at)a,
    pages: ~w(id position title slug description template content visible metadata inserted_at updated_at)a,
    sections: ~w(id position title slug description template content visible metadata page_id inserted_at updated_at)a
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [input: :string])

    Mix.Task.run("app.start", [])

    input = opts[:input] || "priv/repo/data_dump.json"

    unless File.exists?(input) do
      IO.puts("ERROR: File not found: #{input}")
      exit(:shutdown)
    end

    data = input
           |> File.read!()
           |> Jason.decode!()

    IO.puts("Restoring data from #{input}...")

    Repo.transaction(fn ->
      truncate_tables()
      restore_in_order(data)
    end)

    IO.puts("\nRestore complete!")
    for key <- ~w(relationship_types users user_tokens entities media entity_media relationships pages sections) do
      records = Map.get(data, key, [])
      IO.puts("  #{key}: #{length(records)} records")
    end
  end

  defp restore_in_order(data) do
    do_restore(:relationship_types, "relationship_types", "relationship_types", data)
    do_restore(:users, "users", "users", data)
    do_restore(:users_tokens, "user_tokens", "users_tokens", data)
    do_restore(:entities, "entities", "entities", data)
    do_restore(:media, "media", "media", data)
    do_restore(:entity_media, "entity_media", "entity_media", data)
    do_restore(:relationships, "relationships", "relationships", data)
    do_restore(:pages, "pages", "pages", data)
    do_restore(:sections, "sections", "sections", data)
  end

  defp do_restore(col_key, json_key, db_table, data) do
    records = Map.get(data, json_key, [])
    columns = Map.fetch!(@columns, col_key)
    cols_sql = "(" <> Enum.map_join(columns, ", ", &"\"#{&1}\"") <> ")"
    placeholders = "(" <> Enum.map_join(columns, ", ", fn _ -> "?" end) <> ")"
    sql = "INSERT INTO #{db_table} #{cols_sql} VALUES #{placeholders}"

    for record <- records do
      deserialized = deserialize_record(record)
      values = Enum.map(columns, fn col -> Map.get(deserialized, col) end)
      Repo.query!(sql, values)
    end

    IO.puts("  Restored #{length(records)} #{db_table}")
  end

  defp truncate_tables do
    tables_sql = Enum.map_join(@table_order, ", ", &"#{&1}")
    Repo.query!("TRUNCATE TABLE #{tables_sql} CASCADE")
  end

  defp deserialize_record(record) do
    record
    |> Enum.map(fn
      {"hashed_password", s} when is_binary(s) -> {:hashed_password, Base.decode64!(s)}
      {"token", s} when is_binary(s) -> {:token, Base.decode64!(s)}
      {"visible", true} -> {:visible, true}
      {"visible", false} -> {:visible, false}
      {"template", nil} -> {:template, "default"}
      {k, v} when is_map(v) -> {String.to_atom(k), Jason.encode!(v)}
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
    end)
    |> Map.new()
  end
end