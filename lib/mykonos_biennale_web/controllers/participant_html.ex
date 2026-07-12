defmodule MykonosBiennaleWeb.ParticipantHTML do
  use MykonosBiennaleWeb, :html

  alias MykonosBiennale.Content.Entity

  embed_templates "participant_html/*"

  attr :work, :map, required: true

  def work_card(assigns) do
    link = work_link(assigns.work)
    assigns = assign(assigns, :link, link)

    ~H"""
    <div class="group block">
      <%= if @link do %>
        <a href={@link}>
          <div class="aspect-square overflow-hidden rounded-lg bg-neutral-900 mb-3">
            <.work_image work={@work} />
          </div>
        </a>
        <h3 class="text-sm font-medium text-neutral-200">
          <a href={@link} class="hover:text-white transition-colors">
            {work_title(@work.entity)}
          </a>
        </h3>
      <% else %>
        <div class="aspect-square overflow-hidden rounded-lg bg-neutral-900 mb-3">
          <.work_image work={@work} />
        </div>
        <h3 class="text-sm font-medium text-neutral-200">
          {work_title(@work.entity)}
        </h3>
      <% end %>

      <p class="text-xs text-neutral-600 mt-0.5">
        {work_label(@work)}
      </p>

      <%= if @work.events != [] do %>
        <p class="text-xs text-neutral-700 mt-1">
          <%= for e <- Enum.take(@work.events, 2) do %>
            <a
              href={"/event/#{e.id}"}
              class="hover:text-neutral-400 transition-colors"
            >
              {field(e, "title")}
            </a>
          <% end %>
        </p>
      <% end %>
    </div>
    """
  end

  attr :work, :map, required: true

  def work_image(assigns) do
    first = List.first(assigns.work.media)

    assigns = assign(assigns, :first, first)

    ~H"""
    <%= case @first do %>
      <% %{source_type: "upload"} = m -> %>
        <img
          src={media_url(m, size: "card")}
          alt={work_title(@work.entity)}
          class="w-full h-full object-cover group-hover:opacity-80 transition-opacity"
          loading="lazy"
        />
      <% %{source_type: "url", source_url: url} -> %>
        <img
          src={url}
          alt={work_title(@work.entity)}
          class="w-full h-full object-cover group-hover:opacity-80 transition-opacity"
          loading="lazy"
        />
      <% _ -> %>
        <div class="w-full h-full flex items-center justify-center">
          <span class="text-neutral-700 text-xs">No image</span>
        </div>
    <% end %>
    """
  end

  def media_url(media, opts \\ [])
  def media_url(media, opts), do: MykonosBiennale.Uploads.media_url(media, opts)

  defp field(entity, key, default \\ nil)

  defp field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(_, _key, default), do: default

  defp participant_name(%Entity{fields: %{"name" => name}}) when is_binary(name) and name != "",
    do: name

  defp participant_name(%Entity{fields: %{"first_name" => first, "last_name" => last}}),
    do: String.trim("#{first || ""} #{last || ""}")

  defp participant_name(_), do: "Unknown"

  @film_types ["Short Film", "Video", "Animation", "Documentary", "Dance"]

  defp work_link(%{entity: %Entity{type: type, id: id}})
       when type in @film_types do
    "/film/#{id}"
  end

  defp work_link(%{entity: %Entity{id: id}}), do: "/art/#{id}"

  defp work_title(%Entity{identity: identity, fields: fields}) do
    Map.get(fields, "title") || identity || "Untitled"
  end

  defp work_label(%{type: type, roles: roles}) do
    filtered = roles |> Enum.reject(&(&1 in ["artist", ""])) |> Enum.uniq()

    cond do
      type in ["Short Film", "Video", "Animation", "Documentary"] and filtered != [] ->
        "#{type} · #{Enum.join(filtered, ", ")}"

      type == "Dance" and filtered != [] ->
        "Performance · #{Enum.join(filtered, ", ")}"

      type in ["Short Film", "Video", "Animation", "Documentary"] ->
        type

      type == "Dance" ->
        "Performance"

      true ->
        type
    end
  end

  defp work_label(_), do: ""
end
