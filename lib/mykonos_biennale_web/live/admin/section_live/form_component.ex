defmodule MykonosBiennaleWeb.Admin.SectionLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Site.Section
  alias MykonosBiennale.Site
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
        id="section-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input
            field={@form[:page_id]}
            type="select"
            label="Page"
            prompt="Choose a page"
            options={Enum.map(@pages, &{&1.title, &1.id})}
            required
          />
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
            content={Jason.encode!(@section.metadata || %{}, pretty: true)}
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
            Save Section
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
        assign(socket, form: to_form(changeset, as: :section))
      else
        socket
      end

    {:ok, socket}
  end

  def update(%{section: section} = assigns, socket) do
    pages = Site.list_pages()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:pages, pages)
     |> assign_new(:form, fn ->
       changeset = Section.changeset(section, %{})
       to_form(changeset, as: :section)
     end)}
  end

  @impl true
  def handle_event("validate", %{"section" => section_params}, socket) do
    section_params = maybe_slugify(section_params)

    changeset =
      socket.assigns.section
      |> Section.changeset(section_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :section))}
  end

  def handle_event("metadata_changed", %{"content" => content}, socket) do
    case Jason.decode(content) do
      {:ok, metadata} ->
        changeset =
          socket.assigns.form.source
          |> Changeset.put_change(:metadata, metadata)

        {:noreply, assign(socket, form: to_form(changeset, as: :section))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid JSON in metadata")}
    end
  end

  def handle_event("save", %{"section" => section_params}, socket) do
    section_params = maybe_slugify(section_params)
    save_section(socket, socket.assigns.action, section_params)
  end

  defp save_section(socket, :edit, section_params) do
    case Site.update_section(socket.assigns.section, section_params) do
      {:ok, section} ->
        notify_parent({:saved, section})

        {:noreply,
         socket
         |> put_flash(:info, "Section updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not update section")
         |> assign(form: to_form(changeset, as: :section))}
    end
  end

  defp save_section(socket, :new, section_params) do
    case Site.create_section(section_params) do
      {:ok, section} ->
        notify_parent({:saved, section})

        {:noreply,
         socket
         |> put_flash(:info, "Section created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not create section")
         |> assign(form: to_form(changeset, as: :section))}
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
    |> then(&if &1 == "", do: "section", else: "section-#{&1}")
  end

  defp slugify(_), do: "section"
end
