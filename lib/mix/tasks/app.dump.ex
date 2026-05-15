defmodule Mix.Tasks.App.Dump do
  @moduledoc """
  Dumps all application data to a JSON file for migration between databases.

  Usage:
      mix app.dump                      # dumps to priv/repo/data_dump.json
      mix app.dump --output mydata.json # dumps to specified file
  """
  use Mix.Task

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Site.{Page, Section}
  alias MykonosBiennale.Accounts.{User, UserToken}

  @shortdoc "Dump all data to JSON"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [output: :string])

    Mix.Task.run("app.start", [])

    output = opts[:output] || "priv/repo/data_dump.json"

    data = %{
      relationship_types: dump(RelationshipType),
      users: dump(User),
      user_tokens: dump(UserToken),
      entities: dump(Entity),
      media: dump(Media),
      entity_media: dump(EntityMedia),
      relationships: dump(Relationship),
      pages: dump(Page),
      sections: dump(Section)
    }

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Jason.encode!(data, pretty: true))

    counts = for {k, v} <- data, into: %{}, do: {k, length(v)}
    IO.puts("Dumped #{length(Map.keys(counts))} tables to #{output}")
    for {k, v} <- Enum.sort(counts), do: IO.puts("  #{k}: #{v} records")
  end

  defp dump(schema) do
    Repo.all(schema)
    |> Enum.map(&serialize_record/1)
  end

  defp serialize_record(record) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__, :as_subject, :as_object, :media, :sections, :entities, :page, :user, :relationship_type, :subject, :object])
    |> Enum.map(fn
      {:inserted_at, %NaiveDateTime{} = dt} -> {:inserted_at, NaiveDateTime.to_iso8601(dt)}
      {:updated_at, %NaiveDateTime{} = dt} -> {:updated_at, NaiveDateTime.to_iso8601(dt)}
      {:inserted_at, nil} -> {:inserted_at, nil}
      {:updated_at, nil} -> {:updated_at, nil}
      {:search_indexed_at, %NaiveDateTime{} = dt} -> {:search_indexed_at, NaiveDateTime.to_iso8601(dt)}
      {:search_indexed_at, nil} -> {:search_indexed_at, nil}
      {:fields, val} when is_map(val) -> {:fields, val}
      {:metadata, val} when is_map(val) -> {:metadata, val}
      {:hashed_password, bin} when is_binary(bin) -> {:hashed_password, Base.encode64(bin)}
      {:token, bin} when is_binary(bin) -> {:token, Base.encode64(bin)}
      {_k, %Ecto.Association.NotLoaded{}} -> nil
      other -> other
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end
end