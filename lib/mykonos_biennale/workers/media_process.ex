defmodule MykonosBiennale.Workers.MediaProcess do
  @moduledoc """
  Oban worker that generates optimized media variants asynchronously.

  ## Job kinds

    * `%{"kind" => "webp", "media_id" => id}` — generate all WebP sizes for a media record
    * `%{"kind" => "avif", "media_id" => id, "size" => size}` — generate a single AVIF variant
    * `%{"kind" => "press", "media_id" => id}` — generate press-quality JPEG
    * `%{"kind" => "all", "media_id" => id}` — generate WebP sizes + enqueue AVIF + press

  Jobs are uniqued on their args within a 60s window so duplicate enqueues
  during a burst of writes coalesce.
  """

  use Oban.Worker,
    queue: :media,
    unique: [period: 60, keys: [:args]]

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Thumbnail
  alias MykonosBiennale.MediaDir

  @sizes ~w(hero card thumb admin)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"kind" => "webp", "media_id" => id}}) do
    case Repo.get(Media, id) do
      nil -> :ok
      media -> generate_webp_sizes(media)
    end
  end

  def perform(%Oban.Job{args: %{"kind" => "avif", "media_id" => id, "size" => size}}) do
    case Repo.get(Media, id) do
      nil -> :ok
      media -> generate_avif(media, size)
    end
  end

  def perform(%Oban.Job{args: %{"kind" => "press", "media_id" => id}}) do
    case Repo.get(Media, id) do
      nil -> :ok
      media -> generate_press(media)
    end
  end

  def perform(%Oban.Job{args: %{"kind" => "all", "media_id" => id}}) do
    case Repo.get(Media, id) do
      nil -> :ok
      media ->
        generate_webp_sizes(media)
        enqueue_avif_and_press(media.id)
    end
  end

  defp generate_webp_sizes(%Media{slug: slug, source_type: "upload", source_path: path})
       when is_binary(slug) and is_binary(path) do
    unless image_ext?(path) do
      {:ok, :skipped}
    else
      Enum.each(@sizes, fn size ->
        case Thumbnail.ensure_slug_thumbnail(slug, path, size) do
          {:ok, _path} -> :ok
          {:original, _path} -> :ok
        end

        case Thumbnail.ensure_slug_jpeg(slug, path, size) do
          {:ok, _path} -> :ok
          {:original, _path} -> :ok
        end
      end)

      {:ok, :generated}
    end
  end

  defp generate_webp_sizes(_), do: {:ok, :skipped}

  defp generate_avif(%Media{slug: slug, source_type: "upload", source_path: path}, size) do
    unless image_ext?(path) do
      {:ok, :skipped}
    else
      webp_path = MediaDir.path(slug, size, ".webp")
      avif_path = MediaDir.path(slug, size, ".avif")

      cond do
        File.exists?(avif_path) ->
          {:ok, :already_exists}

        File.exists?(webp_path) ->
          generate_avif_from_webp(webp_path, avif_path)

        true ->
          case Thumbnail.ensure_slug_thumbnail(slug, path, size) do
            {:ok, thumb_path} ->
              generate_avif_from_webp(thumb_path, avif_path)

            {:original, _path} ->
              {:ok, :no_source}
          end
      end
    end
  end

  defp generate_avif(_media, _size), do: {:ok, :skipped}

  defp generate_avif_from_webp(webp_path, avif_path) do
    cmd = System.find_executable("magick") || "convert"

    args = [
      webp_path,
      "-quality", "65",
      "-strip",
      avif_path
    ]

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, :generated}

      {error, _code} ->
        require Logger
        Logger.warning("AVIF generation failed for #{webp_path}: #{error}")
        File.rm(avif_path)
        {:error, :avif_failed}
    end
  end

  defp generate_press(%Media{slug: slug, source_type: "upload", source_path: path})
       when is_binary(slug) and is_binary(path) do
    unless image_ext?(path) do
      {:ok, :skipped}
    else
      press_path = MediaDir.path(slug, "press", ".jpg")
      original_path = MykonosBiennale.Uploads.uploads_path(path)

      if File.exists?(press_path) do
        {:ok, :already_exists}
      else
        args = [
          original_path,
          "-resize", "3508x3508>",
          "-quality", "92",
          "-strip",
          press_path
        ]

        cmd = System.find_executable("magick") || "convert"

        case System.cmd(cmd, args, stderr_to_stdout: true) do
          {_, 0} ->
            {:ok, :generated}

          {error, _code} ->
            require Logger
            Logger.warning("Press JPEG generation failed for #{original_path}: #{error}")
            File.rm(press_path)
            {:error, :press_failed}
        end
      end
    end
  end

  defp generate_press(_media), do: {:ok, :skipped}

  defp enqueue_avif_and_press(media_id) do
    Enum.each(@sizes, fn size ->
      %{kind: "avif", media_id: media_id, size: size}
      |> __MODULE__.new()
      |> Oban.insert()
    end)

    %{kind: "press", media_id: media_id}
    |> __MODULE__.new()
    |> Oban.insert()

    :ok
  end

  defp image_ext?(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".tif"]
  end

  def enqueue_webp(media_id) when is_integer(media_id) do
    %{kind: "webp", media_id: media_id} |> __MODULE__.new() |> Oban.insert()
  end

  def enqueue_all(media_id) when is_integer(media_id) do
    %{kind: "all", media_id: media_id} |> __MODULE__.new() |> Oban.insert()
  end

  def enqueue_avif(media_id, size) when is_integer(media_id) and is_binary(size) do
    %{kind: "avif", media_id: media_id, size: size} |> __MODULE__.new() |> Oban.insert()
  end

  def enqueue_press(media_id) when is_integer(media_id) do
    %{kind: "press", media_id: media_id} |> __MODULE__.new() |> Oban.insert()
  end
end