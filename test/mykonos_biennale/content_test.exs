defmodule MykonosBiennale.ContentTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Content
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Content.{Entity, Media, Relationship}

  describe "entity CRUD" do
    test "create_entity/1 creates an entity with valid attrs" do
      {:ok, entity} =
        Content.create_entity(%{
          identity: "Test Entity",
          type: "artwork",
          slug: "test-entity-#{System.unique_integer()}",
          visible: true,
          fields: %{"title" => "Test"}
        })

      assert %Entity{} = entity
      assert entity.identity == "Test Entity"
      assert entity.type == "artwork"
      assert entity.visible == true
      assert entity.fields["title"] == "Test"
    end

    test "get_entity!/1 returns entity by id" do
      entity = ContentFixtures.artwork_fixture()
      assert Content.get_entity!(entity.id).id == entity.id
    end

    test "get_entity_by_slug/1 returns entity by slug" do
      entity = ContentFixtures.artwork_fixture()
      assert Content.get_entity_by_slug(entity.slug).id == entity.id
    end

    test "update_entity/2 updates entity fields" do
      entity = ContentFixtures.artwork_fixture()

      {:ok, updated} =
        Content.update_entity(entity, %{fields: Map.put(entity.fields, "title", "Updated")})

      assert updated.fields["title"] == "Updated"
    end

    test "delete_entity/1 deletes the entity" do
      entity = ContentFixtures.artwork_fixture()
      assert {:ok, _} = Content.delete_entity(entity)
      assert_raise Ecto.NoResultsError, fn -> Content.get_entity!(entity.id) end
    end

    test "list_entities/0 returns all entities" do
      _e1 = ContentFixtures.artwork_fixture(title: "A")
      _e2 = ContentFixtures.artwork_fixture(title: "B")
      entities = Content.list_entities()
      assert length(entities) >= 2
    end
  end

  describe "biennale CRUD" do
    test "create_biennale/1 creates a biennale entity" do
      {:ok, biennale} = Content.create_biennale(%{year: "2025", theme: "Test", visible: true})
      assert %Entity{type: "biennale"} = biennale
      assert biennale.fields["year"] == "2025"
      assert biennale.fields["theme"] == "Test"
      assert biennale.slug == "2025"
    end

    test "get_biennale_by_year/1 returns biennale by year" do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      assert Content.get_biennale_by_year(2025).id == biennale.id
    end

    test "get_biennale_by_year/1 returns nil for non-existent year" do
      assert Content.get_biennale_by_year(1999) == nil
    end

    test "list_biennales/0 returns biennales ordered by year descending" do
      _b1 = ContentFixtures.biennale_fixture(year: 2023)
      _b2 = ContentFixtures.biennale_fixture(year: 2025)
      biennales = Content.list_biennales()
      years = Enum.map(biennales, & &1.fields["year"])
      assert 2025 in years
      assert 2023 in years
    end

    test "update_biennale/2 updates biennale fields" do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      {:ok, updated} = Content.update_biennale(biennale, %{theme: "New Theme"})
      assert updated.fields["theme"] == "New Theme"
    end

    test "delete_biennale/1 deletes the biennale" do
      biennale = ContentFixtures.biennale_fixture(year: 2026)
      assert {:ok, _} = Content.delete_biennale(biennale)
      assert Content.get_biennale_by_year(2026) == nil
    end
  end

  describe "event CRUD" do
    test "create_event/1 creates an event with relationships" do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture()
      project = ContentFixtures.project_fixture()

      {:ok, event} =
        Content.create_event(%{
          title: "Test Exhibition",
          type: "exhibition",
          biennale_id: biennale.id,
          project_id: project.id,
          date: "2025-09-28",
          location: "Gallery"
        })

      assert %Entity{type: "event"} = event
      assert event.fields["title"] == "Test Exhibition"
      assert event.fields["type"] == "exhibition"
      assert event.fields["date"] == "2025-09-28"
      assert event.fields["location"] == "Gallery"
      assert event.fields["show_project"] == true
    end

    test "update_event/2 updates event fields" do
      event = ContentFixtures.event_fixture(title: "Original")
      {:ok, updated} = Content.update_event(event, %{title: "Updated Title"})
      assert updated.fields["title"] == "Updated Title"
    end

    test "delete_event/1 deletes the event" do
      event = ContentFixtures.event_fixture(title: "To Delete")
      assert {:ok, _} = Content.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Content.get_event!(event.id) end
    end

    test "list_events_for_biennale/1 returns events for a biennale year" do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      _event = ContentFixtures.event_fixture(biennale: biennale, title: "2025 Event")

      events = Content.list_events_for_biennale(2025)
      assert Enum.any?(events, &(&1.fields["title"] == "2025 Event"))
    end
  end

  describe "artwork CRUD" do
    test "create_artwork/1 creates an artwork entity" do
      {:ok, artwork} = Content.create_artwork(%{title: "Mona Lisa", date: "2025", medium: "Oil"})
      assert %Entity{type: "artwork"} = artwork
      assert artwork.fields["title"] == "Mona Lisa"
      assert artwork.fields["date"] == "2025"
    end

    test "update_artwork/2 updates artwork fields" do
      artwork = ContentFixtures.artwork_fixture(title: "Old Title")
      {:ok, updated} = Content.update_artwork(artwork, %{title: "New Title"})
      assert updated.fields["title"] == "New Title"
    end

    test "delete_artwork/1 deletes the artwork" do
      artwork = ContentFixtures.artwork_fixture()
      assert {:ok, _} = Content.delete_artwork(artwork)
      assert_raise Ecto.NoResultsError, fn -> Content.get_artwork!(artwork.id) end
    end
  end

  describe "participant CRUD" do
    test "create_participant/1 creates a participant entity" do
      {:ok, participant} = Content.create_participant(%{first_name: "Jane", last_name: "Doe"})
      assert %Entity{type: "participant"} = participant
      assert participant.fields["first_name"] == "Jane"
      assert participant.fields["last_name"] == "Doe"
      assert participant.fields["name"] == "Jane Doe"
    end

    test "update_participant/2 updates participant fields" do
      p = ContentFixtures.participant_fixture(first_name: "Old")
      {:ok, updated} = Content.update_participant(p, %{first_name: "New"})
      assert updated.fields["first_name"] == "New"
    end
  end

  describe "media CRUD" do
    test "create_media/1 creates a media record with auto-generated slug" do
      {:ok, media} =
        Content.create_media(%{source_type: "upload", source_path: "test.jpg", caption: "Test"})

      assert %Media{} = media
      assert media.slug != nil
      assert media.caption == "Test"
    end

    test "get_media_by_slug/1 returns media by slug" do
      media = ContentFixtures.media_fixture(caption: "Find Me")
      assert Content.get_media_by_slug(media.slug).id == media.id
    end

    test "update_media/2 updates media fields" do
      media = ContentFixtures.media_fixture(caption: "Old Caption")
      {:ok, updated} = Content.update_media(media, %{caption: "New Caption"})
      assert updated.caption == "New Caption"
    end

    test "delete_media/1 deletes the media" do
      media = ContentFixtures.media_fixture()
      assert {:ok, _} = Content.delete_media(media)
      assert_raise Ecto.NoResultsError, fn -> Content.get_media!(media.id) end
    end
  end

  describe "media-entity relationships" do
    test "attach_media_to_entity/3 attaches media to an entity" do
      entity = ContentFixtures.artwork_fixture()
      media = ContentFixtures.media_fixture()
      assert {:ok, :attached} = Content.attach_media_to_entity(entity, media)
    end

    test "attach_media_to_entity/3 prevents duplicate attachments" do
      entity = ContentFixtures.artwork_fixture()
      media = ContentFixtures.media_fixture()
      {:ok, :attached} = Content.attach_media_to_entity(entity, media)
      assert {:error, _} = Content.attach_media_to_entity(entity, media)
    end

    test "detach_media_from_entity/2 detaches media from an entity" do
      entity = ContentFixtures.artwork_fixture()
      media = ContentFixtures.media_fixture()
      Content.attach_media_to_entity(entity, media)
      assert {:ok, :detached} = Content.detach_media_from_entity(entity, media)
      assert Content.list_media_for_entity(entity) == []
    end

    test "list_media_for_entity/1 returns media ordered by position" do
      entity = ContentFixtures.artwork_fixture()
      m1 = ContentFixtures.media_fixture(caption: "First")
      m2 = ContentFixtures.media_fixture(caption: "Second")
      Content.attach_media_to_entity(entity, m1, position: 0)
      Content.attach_media_to_entity(entity, m2, position: 1)

      media = Content.list_media_for_entity(entity)
      assert length(media) == 2
      assert hd(media).caption == "First"
    end

    test "reorder_entity_media/2 reorders media positions" do
      entity = ContentFixtures.artwork_fixture()
      m1 = ContentFixtures.media_fixture(caption: "First")
      m2 = ContentFixtures.media_fixture(caption: "Second")
      Content.attach_media_to_entity(entity, m1, position: 0)
      Content.attach_media_to_entity(entity, m2, position: 1)

      Content.reorder_entity_media(entity, [m2.id, m1.id])
      media = Content.list_media_for_entity(entity)
      assert hd(media).id == m2.id
    end
  end

  describe "relationship CRUD" do
    test "create_relationship/1 creates a relationship by slug" do
      ContentFixtures.ensure_relationship_types()
      artwork = ContentFixtures.artwork_fixture()
      event = ContentFixtures.simple_event_fixture()

      {:ok, rel} =
        Content.create_relationship(%{
          slug: "artwork_event",
          subject_id: artwork.id,
          object_id: event.id,
          fields: %{}
        })

      assert %Relationship{} = rel
      assert rel.subject_id == artwork.id
      assert rel.object_id == event.id
    end

    test "create_relationship/1 auto-creates missing relationship type" do
      artwork = ContentFixtures.artwork_fixture()
      event = ContentFixtures.simple_event_fixture()

      {:ok, rel} =
        Content.create_relationship(%{
          slug: "custom_rel_type",
          label: "Custom",
          subject_id: artwork.id,
          object_id: event.id
        })

      assert rel.relationship_type_id != nil
    end

    test "delete_relationship/1 deletes the relationship" do
      ContentFixtures.ensure_relationship_types()
      artwork = ContentFixtures.artwork_fixture()
      event = ContentFixtures.simple_event_fixture()

      {:ok, rel} =
        Content.create_relationship(%{
          slug: "artwork_event",
          subject_id: artwork.id,
          object_id: event.id
        })

      assert {:ok, _} = Content.delete_relationship(rel)
    end
  end

  describe "slugify/1" do
    test "downcases and replaces spaces with dashes" do
      assert Content.slugify("Hello World") == "hello-world"
    end

    test "removes special characters" do
      assert Content.slugify("Héllo! World?") == "hllo-world"
    end

    test "trims leading and trailing dashes" do
      assert Content.slugify("  hello  ") == "hello"
    end
  end
end
