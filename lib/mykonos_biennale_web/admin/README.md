# Backpex Admin Resources

This directory contains Backpex LiveResource modules for the admin interface.

## Pages Admin

**Location**: `/admin/pages`

The Pages admin resource (`PageLive`) provides a full CRUD interface for managing site pages with the following features:

### Features

- ✅ **User-scoped data**: Each user can only see and edit their own pages
- ✅ **Rich code editing**: HTML and metadata fields use the CodeEditor field with syntax highlighting
- ✅ **Search**: Title and slug fields are searchable
- ✅ **Sorting**: Sortable by title, slug, created, and updated dates
- ✅ **JSON metadata**: Metadata field supports JSON editing with validation

### Fields

| Field | Type | Description |
|-------|------|-------------|
| **ID** | Number | Auto-generated identifier (read-only) |
| **Title** | Text | Page title (required, searchable) |
| **Slug** | Text | URL slug (required, searchable) |
| **Template** | Text | Template name (default: "default") |
| **HTML Content** | CodeEditor | HTML content with syntax highlighting (required) |
| **Metadata** | CodeEditor | JSON metadata for SEO, custom properties, etc. |
| **Created At** | DateTime | Timestamp when page was created |
| **Updated At** | DateTime | Timestamp of last update |

### Code Editor Configuration

#### HTML Field
- **Mode**: HTML
- **Theme**: Monokai (dark theme)
- **Lines**: 20-60 visible lines
- **Features**: Line numbers, syntax highlighting, auto-indentation

#### Metadata Field
- **Mode**: JSON
- **Theme**: Monokai (dark theme)
- **Lines**: 10-30 visible lines
- **Validation**: Automatically converts JSON string to map on save

### Accessing the Admin

1. **Login**: Navigate to `/users/log-in` and authenticate
2. **Admin**: Click "Pages" in the sidebar or navigate to `/admin/pages`
3. **Create**: Click "New Page" to create a new page
4. **Edit**: Click on any page row or use the edit action
5. **Delete**: Use the delete action from the item actions menu

### Example Metadata

The metadata field accepts JSON objects. Here's an example:

```json
{
  "seo": {
    "title": "My Page Title",
    "description": "Page description for search engines",
    "keywords": ["keyword1", "keyword2"]
  },
  "social": {
    "og_image": "/images/page-og.jpg",
    "twitter_card": "summary_large_image"
  },
  "custom": {
    "featured": true,
    "category": "blog"
  }
}
```

### User Scoping

The admin automatically scopes all queries to the current authenticated user:

- **List**: Only shows pages created by the current user
- **Create**: Automatically sets `user_id` to current user
- **Edit**: Only allows editing own pages
- **Delete**: Only allows deleting own pages

This is handled by:
1. `item_query/3` function filters all queries by `user_id`
2. `changeset/3` function sets `user_id` on page creation

### Layout

The admin uses the dedicated admin layout (`MykonosBiennaleWeb.Layouts.admin`) which includes:

- Topbar with user dropdown and logout
- Sidebar navigation with "Pages" link
- Responsive layout with Backpex's built-in components

### Routes

The following routes are defined in the router:

```elixir
live "/admin/pages", Admin.PageLive, :index       # List pages
live "/admin/pages/new", Admin.PageLive, :new     # Create page
live "/admin/pages/:id/edit", Admin.PageLive, :edit   # Edit page
live "/admin/pages/:id/show", Admin.PageLive, :show   # View page
```

All routes require authentication and are in the `:require_authenticated_user` live_session.

### Customization

You can customize the Pages admin by editing `/lib/mykonos_biennale_web/admin/page_live.ex`:

- **Add fields**: Add more fields to the `fields/0` callback
- **Change editor themes**: Modify CodeEditor `theme` option (e.g., "github", "tomorrow")
- **Adjust editor size**: Change `min_lines` and `max_lines` options
- **Add validation**: Enhance the `changeset/3` function
- **Add panels**: Group fields using the `panels/0` callback
- **Add actions**: Implement custom item or resource actions

### Tips

1. **JSON Validation**: The metadata field automatically validates JSON on save
2. **Keyboard Shortcuts**: In code editors, use Cmd/Ctrl+S to save
3. **Empty Metadata**: If no metadata is needed, leave the field empty or enter `{}`
4. **Line Numbers**: Line numbers help with debugging HTML and JSON
5. **Dark Theme**: The monokai theme provides excellent contrast for code editing

### Troubleshooting

**Can't see any pages?**
- Make sure you're logged in
- Pages are user-scoped, so you only see your own pages

**JSON validation error?**
- Ensure your JSON is valid (use a JSON validator if needed)
- Empty objects `{}` are valid
- Arrays and nested objects are supported

**HTML not saving?**
- Check the browser console for JavaScript errors
- Ensure Ace Editor loaded (check Network tab)
- Verify the form submits correctly

### Next Steps

To add more admin resources:

1. Create a new LiveResource module in this directory
2. Define fields using Backpex field modules
3. Add routes to the router
4. Add sidebar navigation in the admin layout

Example:

```elixir
# lib/mykonos_biennale_web/admin/product_live.ex
defmodule MykonosBiennaleWeb.Admin.ProductLive do
  use Backpex.LiveResource,
    layout: {MykonosBiennaleWeb.Layouts, :admin},
    adapter_config: [
      schema: MyApp.Catalog.Product,
      repo: MyApp.Repo
    ]

  @impl Backpex.LiveResource
  def singular_name, do: "Product"

  @impl Backpex.LiveResource
  def plural_name, do: "Products"

  @impl Backpex.LiveResource
  def fields do
    [
      # Define your fields here
    ]
  end
end
```

## More Resources

- [Backpex Documentation](https://hexdocs.pm/backpex/)
- [CodeEditor Field Documentation](../fields/README.md)
- [Backpex Field Types](https://hexdocs.pm/backpex/Backpex.Field.html)
