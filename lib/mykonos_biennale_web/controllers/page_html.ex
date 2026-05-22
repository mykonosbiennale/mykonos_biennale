defmodule MykonosBiennaleWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use MykonosBiennaleWeb, :html

  embed_templates "page_html/*"

  def media_url(media, opts \\ [])
  def media_url(media, opts), do: MykonosBiennale.Uploads.media_url(media, opts)
end
