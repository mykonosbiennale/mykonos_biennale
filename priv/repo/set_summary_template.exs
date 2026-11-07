# Seed script to set template = "summary" for incomplete biennales (2023 and before)
# Run with: mix run priv/repo/set_summary_template.exs

alias MykonosBiennale.Repo
alias MykonosBiennale.Content.Entity
import Ecto.Query

# Get all biennales from 2023 and before
biennales = Repo.all(
  from(e in Entity,
    where: e.type == "biennale" and e.visible == true,
    order_by: [desc: fragment("fields->>'year'")]
  )
)
|> Enum.filter(fn b ->
  year = b.fields["year"]
  if year && is_binary(year) do
    String.to_integer(year) <= 2023
  else
    false
  end
end)

IO.puts("Setting 'summary' template for #{length(biennales)} biennales...")

Enum.each(biennales, fn biennale ->
  fields = Map.put(biennale.fields, "template", "summary")

  biennale
  |> Ecto.Changeset.change(fields: fields)
  |> Repo.update!()

  IO.puts("✓ #{biennale.fields["year"]} (#{biennale.fields["theme"]})")
end)

IO.puts("\nDone! These biennales are now using the summary template:")
IO.puts("- They will NOT appear in the Archive section on the home page")
IO.puts("- They ARE still accessible via direct URL: /biennale/{slug}")
IO.puts("- They show: Title, Statement, and section placeholders for participants")
IO.puts("\nAs you complete each year's information, update the template field back to 'default' or 'festival-YYYY'")
