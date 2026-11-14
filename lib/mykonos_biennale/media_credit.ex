defmodule MykonosBiennale.MediaCredit do
  @moduledoc """
  Records who took a photo. The photographer is a participant, stored in the
  media's `metadata` as `"photographer_id"`. The embedded EXIF/IPTC/XMP artist is
  read on upload when `exiftool` is installed, and kept as `"exif_artist"`.
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Repo

  def exif_artist(path) do
    case System.find_executable("exiftool") do
      nil -> nil
      exiftool -> read_artist(exiftool, path)
    end
  end

  defp read_artist(exiftool, path) do
    case System.cmd(exiftool, ["-s3", "-Artist", "-XMP:Creator", "-IPTC:By-line", path],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.find(&(&1 != ""))

      _ ->
        nil
    end
  end

  def photographer_id(%Media{metadata: %{"photographer_id" => id}}) when is_integer(id), do: id
  def photographer_id(_), do: nil

  def put_photographer(metadata, nil), do: Map.delete(metadata || %{}, "photographer_id")
  def put_photographer(metadata, id), do: Map.put(metadata || %{}, "photographer_id", id)

  def participant_name(nil), do: nil

  def participant_name(id) do
    case Repo.get(Entity, id) do
      %Entity{type: "participant", identity: identity} -> identity
      _ -> nil
    end
  end

  def search_participants(query) do
    pattern = "%#{query}%"

    Repo.all(
      from e in Entity,
        where: e.type == "participant" and ilike(e.identity, ^pattern),
        order_by: e.identity,
        limit: 8,
        select: {e.id, e.identity}
    )
  end

  @doc "The one participant whose name equals `name`, ignoring case, or nil."
  def find_participant_by_name(nil), do: nil
  def find_participant_by_name(""), do: nil

  def find_participant_by_name(name) do
    lowered = String.downcase(name)

    case Repo.all(
           from e in Entity,
             where: e.type == "participant" and fragment("lower(?)", e.identity) == ^lowered,
             select: e.id,
             limit: 2
         ) do
      [id] -> id
      _ -> nil
    end
  end
end
