defmodule MykonosBiennaleWeb.EventHTML do
  use MykonosBiennaleWeb, :html

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Uploads

  embed_templates "event_html/*"

  attr :event, Entity, required: true
  attr :biennale, Entity, default: nil

  def event_header(assigns) do
    ~H"""
    <nav class="text-xs text-neutral-600 mb-4 flex items-center gap-2">
      <a href="/" class="hover:text-neutral-400 transition-colors">Home</a>
      <span>/</span>
      <%= if @biennale do %>
        <a href={"/biennale/#{@biennale.slug}"} class="hover:text-neutral-400 transition-colors">
          Mykonos Biennale {field(@biennale, "year")}
        </a>
        <span>/</span>
      <% end %>
      <span class="text-neutral-500">{field(@event, "title")}</span>
    </nav>

    <h1 class="text-4xl md:text-5xl font-light text-white mb-4">
      {field(@event, "title", "Untitled Event")}
    </h1>

    <div class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-neutral-500 mb-2">
      <%= if field(@event, "location") do %>
        <span>{field(@event, "location")}</span>
      <% end %>
      <%= if format_date(field(@event, "date")) do %>
        <span>{format_date(field(@event, "date"))}</span>
      <% end %>
      <%= if format_time(field(@event, "time")) do %>
        <span>{format_time(field(@event, "time"))}</span>
      <% end %>
    </div>
    """
  end

  def media_url(media, opts \\ []),
    do: Uploads.media_url(media, opts)

  defp field(entity, key, default \\ nil)

  defp field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(_, _key, default), do: default

  defp entity_title(%Entity{identity: identity, fields: fields}) do
    Map.get(fields, "title") || Map.get(fields, :title) || identity || "Untitled"
  end

  defp participant_name(%Entity{fields: %{"name" => name}}) when is_binary(name) and name != "",
    do: name

  defp participant_name(%Entity{fields: %{"first_name" => first, "last_name" => last}}),
    do: String.trim("#{first || ""} #{last || ""}")

  defp participant_name(_), do: "Unknown"

  defp format_date(nil), do: nil
  defp format_date(""), do: nil

  defp format_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} ->
        months = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
        "#{Enum.at(months, d.month - 1)} #{d.day}, #{d.year}"

      _ ->
        date
    end
  end

  defp format_time(nil), do: nil
  defp format_time(""), do: nil
  defp format_time(time), do: time
end
