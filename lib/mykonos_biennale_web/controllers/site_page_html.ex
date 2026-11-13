defmodule MykonosBiennaleWeb.SitePageHTML do
  use MykonosBiennaleWeb, :html

  embed_templates "site_page_html/*"

  def render_content(nil, _assigns), do: Phoenix.HTML.raw("")

  # Page content is stored HTML written by admins. It is output as-is and is
  # never evaluated as a template.
  def render_content(content, _assigns) when is_binary(content), do: Phoenix.HTML.raw(content)
end
