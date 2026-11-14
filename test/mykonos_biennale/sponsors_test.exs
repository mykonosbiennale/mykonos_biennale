defmodule MykonosBiennale.SponsorsTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Content
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Sponsors

  setup do
    {:ok,
     b2013: ContentFixtures.biennale_fixture(year: 2013),
     b2015: ContentFixtures.biennale_fixture(year: 2015)}
  end

  describe "save/3" do
    test "creates a sponsor entity with its url and no logo", %{} do
      assert {:ok, sponsor} = Sponsors.save("SEAJETS", "https://www.seajets.com")
      assert sponsor.type == "sponsor"
      assert sponsor.identity == "SEAJETS"
      assert sponsor.fields["url"] == "https://www.seajets.com"
    end

    test "reuses the sponsor with the same name and updates its url", %{} do
      {:ok, first} = Sponsors.save("SEAJETS", "https://old.example")
      {:ok, again} = Sponsors.save("SEAJETS", "https://new.example")

      assert again.id == first.id
      assert again.fields["url"] == "https://new.example"
    end

    test "attaches a logo, replacing any previous logo", %{} do
      {:ok, sponsor} = Sponsors.save("Logo Co", "")
      first_logo = ContentFixtures.media_fixture(caption: "first")
      second_logo = ContentFixtures.media_fixture(caption: "second")

      Sponsors.save("Logo Co", "", sponsor: sponsor, logo: first_logo)
      Sponsors.save("Logo Co", "", sponsor: sponsor, logo: second_logo)

      [entry] = Sponsors.list_sponsors()
      assert entry.logo.id == second_logo.id
    end

    test "renaming onto another sponsor's name is rejected", %{} do
      {:ok, _other} = Sponsors.save("Taken", "")
      {:ok, sponsor} = Sponsors.save("Mine", "")

      assert {:error, :name_taken} = Sponsors.save("Taken", "", sponsor: sponsor)
    end
  end

  describe "link/2 and unlink/2" do
    test "link is idempotent and unlink removes one biennale", %{b2013: b13, b2015: b15} do
      {:ok, sponsor} = Sponsors.save("SEAJETS", "")

      assert :ok = Sponsors.link(sponsor.id, b13.id)
      assert :ok = Sponsors.link(sponsor.id, b13.id)
      assert :ok = Sponsors.link(sponsor.id, b15.id)

      [entry] = Sponsors.list_sponsors()
      assert Enum.sort(entry.years) == ["2013", "2015"]

      assert :ok = Sponsors.unlink(sponsor.id, b13.id)
      [entry] = Sponsors.list_sponsors()
      assert entry.years == ["2015"]
    end
  end

  describe "for_biennale/1" do
    test "lists only the sponsors of that biennale, sorted by name", %{b2013: b13, b2015: b15} do
      {:ok, zeta} = Sponsors.save("Zeta", "https://zeta.example")
      {:ok, alpha} = Sponsors.save("Alpha", "")
      Sponsors.link(zeta.id, b13.id)
      Sponsors.link(alpha.id, b13.id)
      {:ok, other} = Sponsors.save("Other Year", "")
      Sponsors.link(other.id, b15.id)

      assert [%{name: "Alpha", url: "", media: nil}, %{name: "Zeta", url: "https://zeta.example"}] =
               Sponsors.for_biennale(b13.id)
    end
  end

  describe "delete/1" do
    test "removes the sponsor, its links and its logo link but keeps the media", %{b2013: b13} do
      media = ContentFixtures.media_fixture(caption: "keep me")
      {:ok, sponsor} = Sponsors.save("Gone", "", logo: media)
      Sponsors.link(sponsor.id, b13.id)

      assert {:ok, _} = Sponsors.delete(sponsor)
      assert Sponsors.list_sponsors() == []
      assert Sponsors.for_biennale(b13.id) == []
      assert Content.get_media!(media.id)
    end
  end

  describe "legacy migration" do
    test "plans one sponsor per name and applies links and logos", %{b2013: b13, b2015: b15} do
      logo = ContentFixtures.media_fixture(caption: "legacy logo")

      Content.attach_media_to_entity(b13, logo,
        metadata: %{"role" => "sponsor", "name" => "Legacy Co", "url" => "https://legacy.example"}
      )

      Content.attach_media_to_entity(b15, ContentFixtures.media_fixture(caption: "Legacy Co dup"),
        metadata: %{"role" => "sponsor", "name" => "Legacy Co", "url" => ""}
      )

      plan = Sponsors.legacy_plan()
      item = Enum.find(plan, &(&1.name == "Legacy Co"))

      assert item.url == "https://legacy.example"
      assert Enum.sort(item.biennale_ids) == Enum.sort([b13.id, b15.id])
      assert item.media_id == logo.id

      assert :ok = Sponsors.apply_legacy_plan(plan)

      [entry] = Enum.filter(Sponsors.list_sponsors(), &(&1.name == "Legacy Co"))
      assert Enum.sort(entry.years) == ["2013", "2015"]
      assert entry.logo.id == logo.id

      # Legacy rows are left in place for review.
      assert Content.list_entity_media_links_for_entity(b13) != []
    end

    test "applying the plan twice does not duplicate links", %{b2013: b13} do
      Content.attach_media_to_entity(b13, ContentFixtures.media_fixture(caption: "x"),
        metadata: %{"role" => "sponsor", "name" => "Twice", "url" => ""}
      )

      plan = Sponsors.legacy_plan()
      Sponsors.apply_legacy_plan(plan)
      Sponsors.apply_legacy_plan(plan)

      [entry] = Enum.filter(Sponsors.list_sponsors(), &(&1.name == "Twice"))
      assert entry.years == ["2013"]
    end

    test "skips legacy links without a name", %{b2013: b13} do
      Content.attach_media_to_entity(b13, ContentFixtures.media_fixture(caption: "no name"),
        metadata: %{"role" => "sponsor", "url" => ""}
      )

      plan = Sponsors.legacy_plan()
      assert Enum.any?(plan, &(&1.name == ""))
      assert :ok = Sponsors.apply_legacy_plan(plan)
      refute Enum.any?(Sponsors.list_sponsors(), &(&1.name == ""))
    end
  end
end
