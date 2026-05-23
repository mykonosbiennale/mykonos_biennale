defmodule Mix.Tasks.Mb.Media.GenerateAll do
  use Mix.Task

  @shortdoc "Generate WebP thumbnails for all media records"

  @moduledoc """
  Generates WebP thumbnails for all media records that have slugs.
  Optionally enqueues AVIF and press-quality variants via Oban.

  ## Usage

      mix mb.media.generate_all              # Generate WebP thumbnails only
      mix mb.media.generate_all --avif       # Also enqueue AVIF generation
      mix mb.media.generate_all --press      # Also enqueue press JPEG generation
      mix mb.media.generate_all --all        # Generate WebP + enqueue AVIF + press
      mix mb.media.generate_all --force      # Regenerate even if files exist
  """

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Thumbnail
  alias MykonosBiennale.MediaDir
  import Ecto.Query

  @sizes ~w(hero card thumb admin)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [avif: :boolean, press: :boolean, all: :boolean, force: :boolean]
      )

    start_repo()

    generate_avif? = opts[:avif] || opts[:all] || false
    generate_press? = opts[:press] || opts[:all] || false
    force? = opts[:force] || false

    media =
      from(m in Media,
        where: m.source_type == "upload" and not is_nil(m.slug),
        select: {m.id, m.slug, m.source_path},
        order_by: m.id
      )
      |> Repo.all()

    total = length(media)
    Mix.shell().info("Found #{total} media records with slugs")

    MediaDir.ensure_media_dir()

    {generated, skipped, failed} =
      Enum.reduce(media, {0, 0, 0}, fn {id, slug, source_path}, {gen, skip, fail} ->
        if image_ext?(source_path) do
          result = generate_thumbnails(slug, source_path, force?)
          case result do
            :generated ->
              if rem(gen + 1, 50) == 0 do
                Mix.shell().info("  #{gen + 1}/#{total} processed...")
              end

              if generate_avif?, do: enqueue_avif(id)
              if generate_press?, do: enqueue_press(id)
              {gen + 1, skip, fail}

            :skipped ->
              {gen, skip + 1, fail}

            {:error, _} ->
              {gen, skip, fail + 1}
          end
        else
          {gen, skip + 1, fail}
        end
      end)

    Mix.shell().info("Done! Generated: #{generated}, Skipped: #{skipped}, Failed: #{failed}")

    if generate_avif?, do: Mix.shell().info("AVIF jobs enqueued for processing")
    if generate_press?, do: Mix.shell().info("Press JPEG jobs enqueued for processing")
  end

  defp generate_thumbnails(slug, source_path, force?) do
    if force? do
      do_generate(slug, source_path)
    else
      card_path = MediaDir.path(slug, "card", ".webp")
      if File.exists?(card_path) do
        :skipped
      else
        do_generate(slug, source_path)
      end
    end
  end

  defp do_generate(slug, source_path) do
    results =
      Enum.map(@sizes, fn size ->
        case Thumbnail.ensure_slug_thumbnail(slug, source_path, size) do
          {:ok, _} -> :ok
          {:original, _} -> :ok
        end
      end)

    if Enum.all?(results, &(&1 == :ok)) do
      :generated
    else
      {:error, :partial}
    end
  end

  defp enqueue_avif(media_id) do
    Enum.each(@sizes, fn size ->
      %{kind: "avif", media_id: media_id, size: size}
      |> MykonosBiennale.Workers.MediaProcess.new()
      |> Oban.insert()
    end)
  end

  defp enqueue_press(media_id) do
    %{kind: "press", media_id: media_id}
    |> MykonosBiennale.Workers.MediaProcess.new()
    |> Oban.insert()
  end

  defp start_repo do
    repo_opts =
      Application.get_env(:mykonos_biennale, Repo, [])
      |> Keyword.put(:pool_size, 2)
      |> Keyword.put(:queue_target, 5000)
      |> maybe_add_ssl()

    Application.put_env(:mykonos_biennale, Repo, repo_opts)

    [:crypto, :logger, :bcrypt_elixir, :ecto_sql, :postgrex, :oban]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()
  end

  defp maybe_add_ssl(opts) do
    if System.get_env("DATABASE_URL") && System.get_env("DATABASE_SSL") == "true" do
      Keyword.put(opts, :ssl, verify: :verify_none)
    else
      opts
    end
  end

  defp image_ext?(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".tif"]
  end
end