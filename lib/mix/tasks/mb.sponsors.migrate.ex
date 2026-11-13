defmodule Mix.Tasks.Mb.Sponsors.Migrate do
  @moduledoc """
  Migrates legacy sponsor links into sponsor entities and `biennale_sponsor`
  relationships.

  Dry run by default: prints the plan and writes nothing.

      mix mb.sponsors.migrate
      mix mb.sponsors.migrate --apply

  Legacy `entity_media` rows with `role: "sponsor"` are left in place.
  """
  use Mix.Task

  alias MykonosBiennale.Sponsors

  @shortdoc "Migrate legacy sponsor links to sponsor entities (dry run unless --apply)"

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [apply: :boolean])
    Mix.Task.run("app.start")

    plan = Sponsors.legacy_plan()
    skipped = Enum.count(plan, &(&1.name == ""))
    named = Enum.reject(plan, &(&1.name == ""))

    Mix.shell().info(
      "Sponsors to create or update: #{length(named)} (skipped without name: #{skipped})"
    )

    Mix.shell().info(
      "Support links to create: #{Enum.sum(Enum.map(named, &length(&1.biennale_ids)))}"
    )

    Mix.shell().info("Logos to attach: #{Enum.count(named, & &1.media_id)}")

    Enum.each(named, fn item ->
      Mix.shell().info(
        "  #{item.name} -> biennales #{inspect(item.biennale_ids)}#{if item.media_id, do: " (logo #{item.media_id})", else: ""}"
      )
    end)

    if opts[:apply] do
      :ok = Sponsors.apply_legacy_plan(plan)
      Mix.shell().info("Applied.")
    else
      Mix.shell().info("Dry run. Re-run with --apply to write.")
    end
  end
end
