defmodule MykonosBiennale.AntidoteTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.{Antidote, Content, Repo}
  alias MykonosBiennale.Content.Artwork

  defp event do
    {:ok, event} = Content.create_event(%{title: "Treasure Hunt - Antidote", type: "exhibition"})
    event
  end

  defp uploads do
    [
      %{path: "a.jpg", mime_type: "image/jpeg", original_name: "a.jpg"},
      %{path: "b.png", mime_type: "image/png", original_name: "b.png"}
    ]
  end

  test "creates the artist, artwork, media and both links" do
    event = event()

    assert {:ok, %{participant: participant, artwork: artwork, media: media}} =
             Antidote.save_work(
               event,
               %{"first_name" => "Chris", "last_name" => "Golub", "bio" => "Painter"},
               %{"title" => "Antidote", "description" => "Oil on canvas"},
               uploads()
             )

    assert participant.identity == "Chris Golub"
    assert artwork.identity == "Antidote"
    assert length(media) == 2

    assert [%{object_id: pid}] = Artwork.list_linked_participants(artwork)
    assert pid == participant.id
    assert [%{object_id: eid}] = Artwork.list_linked_events(artwork)
    assert eid == event.id
  end

  test "updates an existing participant instead of creating a duplicate" do
    event = event()
    {:ok, existing} = Content.create_participant(%{first_name: "Chris", last_name: "Golub"})
    count = Repo.aggregate(Content.Entity, :count)

    assert {:ok, %{participant: participant}} =
             Antidote.save_work(
               event,
               %{
                 "id" => to_string(existing.id),
                 "first_name" => "Chris",
                 "last_name" => "Golub",
                 "bio" => "New bio"
               },
               %{"title" => "Antidote"},
               []
             )

    assert participant.id == existing.id
    assert participant.fields["bio"] == "New bio"
    assert Repo.aggregate(Content.Entity, :count) == count + 1
  end

  test "defaults a blank artwork title to Untitled" do
    assert {:ok, %{artwork: artwork}} =
             Antidote.save_work(event(), %{"first_name" => "A"}, %{"title" => "  "}, [])

    assert artwork.identity == "Untitled"
  end

  test "rolls back everything when a step fails" do
    event = event()
    before = Repo.aggregate(Content.Entity, :count)

    assert {:error, _} =
             Antidote.save_work(event, %{"first_name" => "A"}, %{"title" => "Work"}, [
               %{path: nil, mime_type: "image/jpeg", original_name: "x.jpg"}
             ])

    assert Repo.aggregate(Content.Entity, :count) == before
  end

  test "add_to_artboard appends media ids without duplicates" do
    event = event()
    {:ok, event} = Antidote.add_to_artboard(event, [5, 6])
    {:ok, event} = Antidote.add_to_artboard(event, [6, 7])
    assert event.fields["artboard_media_ids"] == [5, 6, 7]
  end
end
