defmodule MykonosBiennaleWeb.Admin.PageLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Site.Page
  alias Ecto.Changeset

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900">
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="page-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:position]} type="number" label="Position" required />
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:slug]} type="text" label="Slug" required />
          <.input
            field={@form[:template]}
            type="select"
            label="Template"
            prompt="Choose a template"
            options={[
              {"None", "none"},
              {"Default", "default"}
            ]}
            required
          />
          <.input field={@form[:description]} type="textarea" label="Description" rows="3" />
          <.input field={@form[:content]} type="textarea" label="Content" rows="8" />
          <.input field={@form[:visible]} type="checkbox" label="Visible" />
        </div>

        <div class="mt-6">
          <label class="block text-sm font-semibold text-gray-900 dark:text-gray-100 mb-2">
            Metadata (JSON)
          </label>
          <.live_component
            module={ExEditorWeb.LiveEditor}
            id="metadata-editor"
            content={Jason.encode!(@page.metadata || %{}, pretty: true)}
            language={:json}
            on_change="metadata_changed"
            class="light"
            style="height: 300px;"
          />
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-400 hover:text-white">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Page
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{metadata: metadata} = assigns, socket) when is_map(metadata) do
    changeset =
      socket.assigns[:form] &&
        Changeset.put_change(socket.assigns.form.source, :metadata, metadata)

    socket =
      if changeset do
        assign(socket, form: to_form(changeset, as: :page))
      else
        socket
      end

    {:ok, socket}
  end

  def update(%{page: page} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       changeset = Page.changeset(page, %{})
       to_form(changeset, as: :page)
     end)}
  end

  @impl true
  def handle_event("validate", %{"page" => page_params}, socket) do
    page_params = maybe_slugify(page_params)

    changeset =
      socket.assigns.page
      |> Page.changeset(page_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :page))}
  end

  def handle_event("metadata_changed", %{"content" => content}, socket) do
    case Jason.decode(content) do
      {:ok, metadata} ->
        changeset =
          socket.assigns.form.source
          |> Changeset.put_change(:metadata, metadata)

        {:noreply, assign(socket, form: to_form(changeset, as: :page))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid JSON in metadata")}
    end
  end

  def handle_event("save", %{"page" => page_params}, socket) do
    page_params = maybe_slugify(page_params)
    save_page(socket, socket.assigns.action, page_params)
  end

  defp save_page(socket, :edit, page_params) do
    case MykonosBiennale.Site.update_page(socket.assigns.page, page_params) do
      {:ok, page} ->
        notify_parent({:saved, page})

        {:noreply,
         socket
         |> put_flash(:info, "Page updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not update page")
         |> assign(form: to_form(changeset, as: :page))}
    end
  end

  defp save_page(socket, :new, page_params) do
    case MykonosBiennale.Site.create_page(page_params) do
      {:ok, page} ->
        notify_parent({:saved, page})

        {:noreply,
         socket
         |> put_flash(:info, "Page created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not create page")
         |> assign(form: to_form(changeset, as: :page))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp maybe_slugify(params) do
    if params["slug"] == "" || params["slug"] == nil do
      title = params["title"] || ""
      Map.put(params, "slug", slugify(title))
    else
      params
    end
  end

  defp slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> then(&if &1 == "", do: "page", else: "page-#{&1}")
  end

  defp slugify(_), do: "page"
end
