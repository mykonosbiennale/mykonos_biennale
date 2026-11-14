defmodule MykonosBiennale.Antidote do
  @moduledoc """
  Creates an artist and one artwork with its images, links both to an event,
  and lets an admin choose which images appear on that event's art board.
  """

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Artwork
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Participant
  alias MykonosBiennale.Repo

  @doc """
  Saves the artist, the artwork, its media and all links in one transaction.

  `uploads` is a list of `%{path: stored_filename, mime_type: _, original_name: _}`.
  `artist_attrs` may include `"id"` to update an existing participant.
  """
  def save_work(%Entity{} = event, artist_attrs, artwork_attrs, uploads) do
    title = blank_to_nil(artwork_attrs["title"]) || "Untitled"

    Repo.transaction(
      fn ->
        with {:ok, participant} <- save_artist(artist_attrs),
             {:ok, artwork} <- create_artwork(title, artwork_attrs),
             {:ok, media} <- attach_uploads(artwork, uploads),
             {:ok, _} <- Artwork.attach_participant(artwork, participant, "artist"),
             {:ok, _} <- Artwork.attach_event(artwork, event) do
          %{participant: participant, artwork: artwork, media: media}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end,
      timeout: :timer.minutes(5)
    )
  end

  @doc """
  Adds media ids to an event's art board, keeping the existing order.
  """
  def add_to_artboard(%Entity{} = event, media_ids) do
    current = event.fields["artboard_media_ids"] || []
    new_ids = Enum.uniq(current ++ media_ids)
    Content.update_event(event, %{artboard_media_ids: new_ids})
  end

  defp save_artist(%{"id" => id} = attrs) when is_binary(id) and id != "" do
    participant = Content.get_participant!(String.to_integer(id))
    update_attrs = artist_fields(attrs)
    Participant.update(participant, update_attrs)
  end

  defp save_artist(attrs) do
    Participant.create(artist_fields(attrs))
  end

  defp artist_fields(attrs) do
    first = String.trim(attrs["first_name"] || "")
    last = String.trim(attrs["last_name"] || "")
    name = String.trim(attrs["name"] || "")
    name = if name == "", do: String.trim("#{first} #{last}"), else: name

    %{
      first_name: first,
      last_name: last,
      name: name,
      bio: blank_to_nil(attrs["bio"]),
      statement: blank_to_nil(attrs["statement"])
    }
  end

  defp create_artwork(title, attrs) do
    Artwork.create(%{
      title: title,
      description: blank_to_nil(attrs["description"])
    })
  end

  defp attach_uploads(artwork, uploads) do
    Enum.reduce_while(uploads, {:ok, []}, fn upload, {:ok, acc} ->
      with {:ok, media} <-
             Content.create_media(%{
               caption: upload.original_name,
               source_type: "upload",
               source_path: upload.path,
               mime_type: upload.mime_type,
               original_name: upload.original_name
             }),
           {:ok, _} <- Content.attach_media_to_entity(artwork, media) do
        {:cont, {:ok, [media | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, media} -> {:ok, Enum.reverse(media)}
      error -> error
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
