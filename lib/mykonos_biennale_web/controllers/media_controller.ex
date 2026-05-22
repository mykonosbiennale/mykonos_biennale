defmodule MykonosBiennaleWeb.MediaController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Thumbnail

  @sizes %{
    "hero"    => {1920, 1080},
    "card"    => {800, 600},
    "thumb"   => {400, 300},
    "admin"   => {300, 300}
  }

  def show(conn, %{"dimensions" => dimensions, "filename" => filename}) do
    {width, height} = parse_dimensions(dimensions)

    original_filename =
      filename
      |> Path.rootname()
      |> then(&(&1 <> original_ext(filename)))

    case Thumbnail.ensure_thumbnail(original_filename, width, height) do
      {:ok, thumb_path} ->
        conn
        |> put_resp_header("content-type", "image/webp")
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_file(200, thumb_path)

      {:original, original_path} ->
        ext = Path.extname(original_filename) |> String.downcase()
        mime = mime_type(ext)
        conn
        |> put_resp_header("content-type", mime)
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_file(200, original_path)
    end
  end

  defp parse_dimensions(dim) do
    case Map.get(@sizes, dim) do
      {w, h} -> {w, h}
      nil ->
        case String.split(dim, "x") do
          [w, h] -> {String.to_integer(w), String.to_integer(h)}
          _ -> {1200, 800}
        end
    end
  end

  defp original_ext(filename) do
    ext = Path.extname(filename) |> String.downcase()
    if ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"], do: ext, else: ".jpg"
  end

  defp mime_type(".jpg"), do: "image/jpeg"
  defp mime_type(".jpeg"), do: "image/jpeg"
  defp mime_type(".png"), do: "image/png"
  defp mime_type(".gif"), do: "image/gif"
  defp mime_type(".webp"), do: "image/webp"
  defp mime_type(".bmp"), do: "image/bmp"
  defp mime_type(_), do: "application/octet-stream"
end