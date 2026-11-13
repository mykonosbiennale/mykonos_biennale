defmodule MykonosBiennaleWeb.BiennaleHTMLTest do
  use MykonosBiennale.DataCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennaleWeb.BiennaleHTML

  describe "date and time formatting" do
    test "format_date handles nil, ISO strings, Date structs and bad input" do
      assert BiennaleHTML.format_date(nil) == nil
      assert BiennaleHTML.format_date("2025-09-27") == "September 27, 2025"
      assert BiennaleHTML.format_date("not-a-date") == "not-a-date"
      assert BiennaleHTML.format_date(~D[2025-10-05]) == "October 05, 2025"
    end

    test "format_time converts 24-hour times and keeps bad input" do
      assert BiennaleHTML.format_time(nil) == nil
      assert BiennaleHTML.format_time("14:30") == "2:30 PM"
      assert BiennaleHTML.format_time("00:05") == "12:05 AM"
      assert BiennaleHTML.format_time("12:00") == "12:00 PM"
      assert BiennaleHTML.format_time("tba") == "tba"
    end

    test "format_day gives weekday and day/month and keeps bad input" do
      assert BiennaleHTML.format_day(nil) == nil
      assert BiennaleHTML.format_day("2025-09-27") == "Saturday, 27/09"
      assert BiennaleHTML.format_day("nope") == "nope"
    end
  end

  describe "render_content" do
    test "nil content renders empty" do
      assert Phoenix.HTML.safe_to_string(BiennaleHTML.render_content(nil, %{})) == ""
    end

    test "plain HTML passes through" do
      assert Phoenix.HTML.safe_to_string(BiennaleHTML.render_content("<p>Plain</p>", %{})) =~
               "<p>Plain</p>"
    end

    test "template tags are shown as text, never evaluated" do
      content = "<p><%= System.cmd(\"id\", []) %></p>"
      html = BiennaleHTML.render_content(content, %{label: "x"})
      assert Phoenix.HTML.safe_to_string(html) == content
    end
  end

  describe "summary_section" do
    test "renders the title and joined names" do
      html =
        render_component(&BiennaleHTML.summary_section/1,
          title: "Artists",
          names: ["Ann", "Ben"],
          border: "border-red-600",
          text: "text-red-400"
        )

      assert html =~ "Artists"
      assert html =~ "Ann · Ben"
    end

    test "renders nothing when there are no names" do
      html =
        render_component(&BiennaleHTML.summary_section/1,
          title: "Empty",
          names: [],
          border: "b",
          text: "t"
        )

      refute html =~ "Empty"
    end
  end

  describe "archive_teaser" do
    test "lists every edition, including summary templates, and links to the full archive past eight" do
      ContentFixtures.ensure_relationship_types()

      biennales =
        for year <- 2010..2018 do
          ContentFixtures.biennale_fixture(
            year: year,
            theme: "Edition #{year}",
            template: "default"
          )
        end

      summary = ContentFixtures.biennale_fixture(year: 2030, theme: "Hidden", template: "summary")
      media = ContentFixtures.media_fixture(caption: "Tile")
      media_map = %{hd(biennales).id => [media]}

      html =
        render_component(&BiennaleHTML.archive_teaser/1,
          biennales: biennales ++ [summary],
          media_map: media_map
        )

      assert html =~ "Edition 2010"
      assert html =~ "View All Editions"
      assert html =~ "Hidden"
      assert html =~ "background-image"
    end

    test "omits the full archive link for a short list" do
      ContentFixtures.ensure_relationship_types()

      biennale =
        ContentFixtures.biennale_fixture(year: 2020, theme: "Only One", template: "default")

      html =
        render_component(&BiennaleHTML.archive_teaser/1, biennales: [biennale], media_map: %{})

      assert html =~ "Only One"
      refute html =~ "View All Editions"
    end
  end

  describe "media and helpers" do
    test "media_url returns a url for an uploaded media" do
      media = ContentFixtures.media_fixture(caption: "URL media")
      assert is_binary(BiennaleHTML.media_url(media, size: "hero"))
    end

    test "template_options lists the default and discovered templates" do
      values = Enum.map(BiennaleHTML.template_options(), &elem(&1, 1))
      assert "default" in values
      assert "none" in values
      assert "festival-2025" in values
    end

    test "build_label includes the version and render mode" do
      assert BiennaleHTML.build_label("L") =~ " · L"
    end
  end
end
