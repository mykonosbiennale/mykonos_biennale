defmodule MykonosBiennaleWeb.ArchiveHTML do
  @moduledoc """
  Templates for ArchiveController (/archive).
  """
  use MykonosBiennaleWeb, :html

  embed_templates "archive_html/*"

  attr :biennale, :map, required: true

  def biennale_card(assigns) do
    ~H"""
    <a
      href={~p"/biennale/#{@biennale.slug}"}
      class="group block bg-gray-900 border border-gray-800 hover:border-gray-600 transition-all duration-300"
    >
      <div class="aspect-square bg-black relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-gray-800 to-black group-hover:scale-105 transition-transform duration-500">
        </div>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="text-6xl md:text-7xl font-bold text-gray-600 group-hover:text-gray-400 transition-colors">
            {@biennale.fields["year"]}
          </span>
        </div>
      </div>

      <div class="p-6">
        <h3 class="text-2xl font-bold uppercase mb-2 group-hover:text-gray-300 transition-colors">
          {@biennale.fields["theme"]}
        </h3>

        <%= if @biennale.fields["statement"] do %>
          <p class="text-gray-400 text-sm line-clamp-3">
            {@biennale.fields["statement"]}
          </p>
        <% end %>

        <%= if date_range(@biennale) do %>
          <p class="text-xs text-gray-500 mt-4 uppercase tracking-wider">
            {date_range(@biennale)}
          </p>
        <% end %>
      </div>
    </a>
    """
  end

  # Returns nil unless both dates parse, so one bad row cannot break the page.
  defp date_range(biennale) do
    with start_str when is_binary(start_str) <- biennale.fields["start_date"],
         end_str when is_binary(end_str) <- biennale.fields["end_date"],
         {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str) do
      "#{Calendar.strftime(start_date, "%B %d")} – #{Calendar.strftime(end_date, "%B %d, %Y")}"
    else
      _ -> nil
    end
  end
end
