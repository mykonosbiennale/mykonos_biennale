defmodule MykonosBiennale.MediaCreditTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.MediaCredit

  defp participant(name) do
    {:ok, p} = Content.create_participant(%{name: name, first_name: "", last_name: name})
    p
  end

  test "stores and reads the photographer id in metadata" do
    meta = MediaCredit.put_photographer(%{"role" => "x"}, 42)
    assert meta == %{"role" => "x", "photographer_id" => 42}
    assert MediaCredit.photographer_id(%Media{metadata: meta}) == 42
    assert MediaCredit.put_photographer(meta, nil) == %{"role" => "x"}
    assert MediaCredit.photographer_id(%Media{metadata: nil}) == nil
  end

  test "finds a participant by name ignoring case" do
    p = participant("Thanos")
    assert MediaCredit.find_participant_by_name("thanos") == p.id
    assert MediaCredit.find_participant_by_name("Nobody Here") == nil
  end

  test "search returns matching participants" do
    p = participant("Lydia Venieri")
    assert {p.id, "Lydia Venieri"} in MediaCredit.search_participants("venieri")
  end

  test "reads the artist from an embedded EXIF tag" do
    working? =
      case System.find_executable("exiftool") do
        nil -> false
        exiftool -> match?({_, 0}, System.cmd(exiftool, ["-ver"], stderr_to_stdout: true))
      end

    if working? do
      path = Path.join(System.tmp_dir!(), "credit-#{System.unique_integer([:positive])}.jpg")
      File.cp!("test/support/fixtures/files/test.jpg", path)
      {_, 0} = System.cmd("exiftool", ["-overwrite_original", "-Artist=Thanos Test", path])
      assert MediaCredit.exif_artist(path) == "Thanos Test"
      File.rm!(path)
    end
  end
end
