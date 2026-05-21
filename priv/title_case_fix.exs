alias MykonosBiennale.Content.Entity
alias MykonosBiennale.Repo
import Ecto.Query

# 1. Title-case ALL-CAPS names
all_caps =
  Repo.all(
    from ent in Entity,
      where:
        ent.type == "participant" and
          fragment("? ->> 'import_model'", ent.fields) == "filmfestival.credit" and
          ent.identity == fragment("UPPER(?)", ent.identity) and
          fragment("length(?)", ent.identity) > 4
  )

IO.puts("Found #{length(all_caps)} ALL-CAPS participants")

caps_count =
  Enum.reduce(all_caps, 0, fn ent, acc ->
    name = String.trim(ent.identity)
    title_name = String.split(name, ~r/\s+/) |> Enum.map_join(" ", &String.capitalize/1)

    if name == title_name do
      acc
    else
      parts = String.split(title_name, ~r/\s+/)
      ln = List.last(parts) || ""
      fst = Enum.join(Enum.take(parts, length(parts) - 1), " ")

      updated_fields =
        ent.fields
        |> Map.put("name", title_name)
        |> Map.put("first_name", fst)
        |> Map.put("last_name", ln)
        |> Map.put("import_name", String.downcase(String.replace(title_name, ~r/\s+/, " ")))

      ent |> Ecto.Changeset.change(fields: updated_fields, identity: title_name) |> Repo.update!()
      acc + 1
    end
  end)

IO.puts("Title-cased #{caps_count} names")

# 2. Fix double spaces
double_space =
  Repo.all(
    from ent in Entity,
      where:
        ent.type == "participant" and
          fragment("? ->> 'import_model'", ent.fields) == "filmfestival.credit" and
          fragment("INSTR(?, '  ')", ent.identity) > 0
  )

IO.puts("Found #{length(double_space)} double-space participants")

ds_count =
  Enum.reduce(double_space, 0, fn ent, acc ->
    name = String.replace(ent.identity, ~r/\s+/, " ") |> String.trim()
    fields_name = String.replace(ent.fields["name"] || "", ~r/\s+/, " ") |> String.trim()
    fst = String.replace(ent.fields["first_name"] || "", ~r/\s+/, " ") |> String.trim()
    ln = String.replace(ent.fields["last_name"] || "", ~r/\s+/, " ") |> String.trim()

    updated_fields =
      ent.fields
      |> Map.put("name", fields_name)
      |> Map.put("first_name", fst)
      |> Map.put("last_name", ln)
      |> Map.put("import_name", String.downcase(String.replace(fields_name, ~r/\s+/, " ")))

    ent |> Ecto.Changeset.change(fields: updated_fields, identity: name) |> Repo.update!()
    acc + 1
  end)

IO.puts("Fixed #{ds_count} double-space names")
IO.puts("Done! Total: #{caps_count + ds_count} fixes")
