defmodule MykonosBiennaleWeb.Admin.RelationshipLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship}
  alias Ecto.Changeset

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900">
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="relationship-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-semibold text-gray-900 mb-1">Relationship Type</label>
            <select
              name="relationship[relationship_type_id]"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">Select type...</option>
              <%= for rt <- @relationship_types do %>
                <option
                  value={rt.id}
                  selected={to_string(rt.id) == @form[:relationship_type_id].value}
                >
                  {rt.slug} ({rt.label})
                </option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-900 mb-1">Subject Entity</label>
            <select
              name="relationship[subject_id]"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">Select subject...</option>
              <%= for e <- @entities do %>
                <option
                  value={e.id}
                  selected={to_string(e.id) == @form[:subject_id].value}
                >
                  {entity_label(e)} [{e.type}]
                </option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-900 mb-1">Object Entity</label>
            <select
              name="relationship[object_id]"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900"
            >
              <option value="">Select object...</option>
              <%= for e <- @entities do %>
                <option
                  value={e.id}
                  selected={to_string(e.id) == @form[:object_id].value}
                >
                  {entity_label(e)} [{e.type}]
                </option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-900 mb-1">Fields (JSON)</label>
            <textarea
              name="relationship[fields]"
              rows="3"
              class="w-full rounded-lg border-gray-300 bg-white text-gray-900 px-3 py-2 font-mono text-sm"
              placeholder='{"roles": "editor, sound"}'
            >{format_fields_value(@form[:fields].value)}</textarea>
          </div>
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Relationship
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{relationship: relationship} = assigns, socket) do
    relationship_types = Map.get(assigns, :relationship_types, Content.list_relationship_types())

    entities =
      Repo.all(
        from e in Entity,
          order_by: [asc: e.type, asc: e.identity],
          select: %{id: e.id, type: e.type, identity: e.identity, fields: e.fields}
      )

    changeset =
      if relationship.id do
        preloaded = Repo.preload(relationship, [:subject, :object, :relationship_type])

        Relationship.changeset(preloaded, %{
          relationship_type_id: preloaded.relationship_type_id,
          subject_id: preloaded.subject_id,
          object_id: preloaded.object_id,
          fields: preloaded.fields
        })
      else
        Relationship.changeset(relationship, %{})
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:relationship_types, relationship_types)
     |> assign(:entities, entities)
     |> assign(:form, to_form(changeset, as: :relationship))}
  end

  @impl true
  def handle_event("validate", %{"relationship" => params}, socket) do
    changeset =
      socket.assigns.relationship
      |> Relationship.changeset(parse_params(params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :relationship))}
  end

  def handle_event("save", %{"relationship" => params}, socket) do
    save_relationship(socket, socket.assigns.action, parse_params(params))
  end

  defp save_relationship(socket, :edit, params) do
    case Content.update_relationship(socket.assigns.relationship, params) do
      {:ok, rel} ->
        send(self(), {__MODULE__, {:saved, rel}})

        {:noreply,
         socket
         |> put_flash(:info, "Relationship updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :relationship))}
    end
  end

  defp save_relationship(socket, :new, params) do
    case Content.create_relationship(params) do
      {:ok, rel} ->
        send(self(), {__MODULE__, {:saved, rel}})

        {:noreply,
         socket
         |> put_flash(:info, "Relationship created")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :relationship))}
    end
  end

  defp parse_params(params) do
    params
    |> maybe_put_id(:relationship_type_id)
    |> maybe_put_id(:subject_id)
    |> maybe_put_id(:object_id)
    |> parse_fields()
  end

  defp maybe_put_id(params, key) do
    case Map.get(params, to_string(key)) do
      "" -> Map.put(params, to_string(key), nil)
      v when is_binary(v) -> Map.put(params, to_string(key), String.to_integer(v))
      _ -> params
    end
  end

  defp parse_fields(params) do
    case Map.get(params, "fields") do
      nil -> Map.put(params, "fields", nil)
      "" -> Map.put(params, "fields", nil)
      raw ->
        case Jason.decode(raw) do
          {:ok, decoded} -> Map.put(params, "fields", decoded)
          {:error, _} -> Map.put(params, "fields", nil)
        end
    end
  end

  defp entity_label(%Entity{identity: identity}) when is_binary(identity) and identity != "",
    do: identity

  defp entity_label(%{identity: identity}) when is_binary(identity) and identity != "",
    do: identity

  defp entity_label(%Entity{fields: fields}) when is_map(fields) do
    Map.get(fields, "name") ||
      "#{Map.get(fields, "first_name", "")} #{Map.get(fields, "last_name", "")}"
      |> String.trim()
  end

  defp entity_label(%{fields: fields}) when is_map(fields) do
    Map.get(fields, "name") ||
      "#{Map.get(fields, "first_name", "")} #{Map.get(fields, "last_name", "")}"
      |> String.trim()
  end

  defp entity_label(%{id: id}), do: "##{id}"

  defp format_fields_value(nil), do: ""

  defp format_fields_value(fields) when is_map(fields) and map_size(fields) > 0 do
    Jason.encode!(fields, pretty: true)
  end

  defp format_fields_value(_), do: ""
end
