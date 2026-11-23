defmodule Mix.Tasks.Mb.Media.Dedupe do
  @moduledoc """
  Fingerprints every media record and merges the duplicates.

  Duplicates are media with the same file bytes (uploads), URL or embed code. One
  record per group is kept: the one with the best caption, otherwise the oldest. Links,
  art boards and relationship images are repointed to it, and the others are retired
  (hidden with `visible: false`, pointing at the kept record). Nothing is deleted.

      mix mb.media.dedupe --dry-run   # report only, change nothing
      mix mb.media.dedupe             # merge

  Run this before migrating the unique fingerprint index.
  """
  use Mix.Task

  alias MykonosBiennale.Content.MediaDedupe

  @shortdoc "Merge duplicate media records"

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [dry_run: :boolean])
    Mix.Task.run("app.start")

    report = MediaDedupe.run(dry_run: Keyword.get(opts, :dry_run, false))

    Mix.shell().info("""
    #{if report.dry_run, do: "Dry run (nothing changed)", else: "Retired duplicates"}
      media records:            #{report.media}
      fingerprinted now:        #{report.fingerprinted}
      upload files missing:     #{report.missing_files}
      duplicate groups:         #{report.duplicate_groups}
      records retired:          #{report.retired}
      entity links moved:       #{report.links_moved}
      art boards updated:       #{report.artboards_updated}
      relationship images moved: #{report.relationships_updated}
    """)
  end
end
