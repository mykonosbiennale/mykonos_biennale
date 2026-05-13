defmodule Mix.Tasks.Mb.Reindex do
  @moduledoc """
  Rebuild the search index for every entity and media.

  Runs the indexer synchronously (no Oban enqueue) so a fresh DB or a recently
  changed indexer can be backfilled in one go.

      mix mb.reindex

  Options:

    * `--async` enqueue Oban jobs instead of running inline
  """
  use Mix.Task

  alias MykonosBiennale.{Repo}
  alias MykonosBiennale.Content.{Entity, Media}
  alias MykonosBiennale.Search.Indexer
  alias MykonosBiennale.Workers.SearchReindex

  @shortdoc "Rebuild search_index for all entities and media"

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [async: :boolean])
    Mix.Task.run("app.start")

    import Ecto.Query

    entity_ids = Repo.all(from e in Entity, select: e.id)
    media_ids = Repo.all(from m in Media, select: m.id)

    Mix.shell().info("Reindexing #{length(entity_ids)} entities and #{length(media_ids)} media...")

    if opts[:async] do
      Enum.each(entity_ids, &SearchReindex.enqueue_entity/1)
      Enum.each(media_ids, &SearchReindex.enqueue_media/1)
      Mix.shell().info("Enqueued.")
    else
      Enum.each(entity_ids, &Indexer.index_entity/1)
      Enum.each(media_ids, &Indexer.index_media/1)
      Mix.shell().info("Done.")
    end
  end
end
