defmodule MykonosBiennale.DataTest do
  use MykonosBiennale.DataCase

  alias MykonosBiennale.Data

  describe "entities" do
    alias MykonosBiennale.Data.Entity

    import MykonosBiennale.DataFixtures

    @invalid_attrs %{visible: nil, fields: nil, identity: nil}

    test "list_entities/0 returns all entities" do
      entity = entity_fixture()
      assert Data.list_entities() == [entity]
    end

    test "get_entity!/1 returns the entity with given id" do
      entity = entity_fixture()
      assert Data.get_entity!(entity.id) == entity
    end

    test "create_entity/1 with valid data creates a entity" do
      valid_attrs = %{visible: true, fields: %{}, identity: "some identity"}

      assert {:ok, %Entity{} = entity} = Data.create_entity(valid_attrs)
      assert entity.visible == true
      assert entity.fields == %{}
      assert entity.identity == "some identity"
    end

    test "create_entity/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Data.create_entity(@invalid_attrs)
    end

    test "update_entity/2 with valid data updates the entity" do
      entity = entity_fixture()
      update_attrs = %{visible: false, fields: %{}, identity: "some updated identity"}

      assert {:ok, %Entity{} = entity} = Data.update_entity(entity, update_attrs)
      assert entity.visible == false
      assert entity.fields == %{}
      assert entity.identity == "some updated identity"
    end

    test "update_entity/2 with invalid data returns error changeset" do
      entity = entity_fixture()
      assert {:error, %Ecto.Changeset{}} = Data.update_entity(entity, @invalid_attrs)
      assert entity == Data.get_entity!(entity.id)
    end

    test "delete_entity/1 deletes the entity" do
      entity = entity_fixture()
      assert {:ok, %Entity{}} = Data.delete_entity(entity)
      assert_raise Ecto.NoResultsError, fn -> Data.get_entity!(entity.id) end
    end

    test "change_entity/1 returns a entity changeset" do
      entity = entity_fixture()
      assert %Ecto.Changeset{} = Data.change_entity(entity)
    end
  end

  describe "relationships" do
    alias MykonosBiennale.Data.Relationship

    import MykonosBiennale.DataFixtures

    @invalid_attrs %{name: nil, fields: nil, slug: nil}

    test "list_relationships/0 returns all relationships" do
      relationship = relationship_fixture()
      assert Data.list_relationships() == [relationship]
    end

    test "get_relationship!/1 returns the relationship with given id" do
      relationship = relationship_fixture()
      assert Data.get_relationship!(relationship.id) == relationship
    end

    test "create_relationship/1 with valid data creates a relationship" do
      valid_attrs = %{name: "some name", fields: %{}, slug: "some slug"}

      assert {:ok, %Relationship{} = relationship} = Data.create_relationship(valid_attrs)
      assert relationship.name == "some name"
      assert relationship.fields == %{}
      assert relationship.slug == "some slug"
    end

    test "create_relationship/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Data.create_relationship(@invalid_attrs)
    end

    test "update_relationship/2 with valid data updates the relationship" do
      relationship = relationship_fixture()
      update_attrs = %{name: "some updated name", fields: %{}, slug: "some updated slug"}

      assert {:ok, %Relationship{} = relationship} = Data.update_relationship(relationship, update_attrs)
      assert relationship.name == "some updated name"
      assert relationship.fields == %{}
      assert relationship.slug == "some updated slug"
    end

    test "update_relationship/2 with invalid data returns error changeset" do
      relationship = relationship_fixture()
      assert {:error, %Ecto.Changeset{}} = Data.update_relationship(relationship, @invalid_attrs)
      assert relationship == Data.get_relationship!(relationship.id)
    end

    test "delete_relationship/1 deletes the relationship" do
      relationship = relationship_fixture()
      assert {:ok, %Relationship{}} = Data.delete_relationship(relationship)
      assert_raise Ecto.NoResultsError, fn -> Data.get_relationship!(relationship.id) end
    end

    test "change_relationship/1 returns a relationship changeset" do
      relationship = relationship_fixture()
      assert %Ecto.Changeset{} = Data.change_relationship(relationship)
    end
  end
end
