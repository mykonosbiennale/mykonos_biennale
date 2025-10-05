# Custom Backpex Fields

## CodeEditor Field

A custom Backpex field that provides a rich code editing experience using Ace Editor.

### Features

- **Syntax Highlighting**: Support for multiple programming languages
- **Multiple Themes**: Choose from various editor themes (monokai, github, tomorrow, etc.)
- **Line Numbers**: Optional gutter display with line numbers
- **Auto-indentation**: Smart indentation based on language
- **Keyboard Shortcuts**: Includes Cmd/Ctrl+S to save
- **Responsive**: Adapts to container size with min/max line settings
- **Index Inline Editing**: Supports editing directly in index views

### Installation

The field is already set up and ready to use. Ace Editor is loaded from CDN in the root layout.

### Usage

In your Backpex resource configuration, use the field like this:

```elixir
def fields do
  [
    content: %{
      module: MykonosBiennaleWeb.Fields.CodeEditor,
      label: "HTML Content",
      mode: "html",
      theme: "monokai",
      min_lines: 15,
      max_lines: 50,
      font_size: 14,
      show_gutter: true,
      show_print_margin: false
    },
    css_code: %{
      module: MykonosBiennaleWeb.Fields.CodeEditor,
      label: "CSS Styles",
      mode: "css",
      theme: "github",
      min_lines: 10,
      max_lines: 30
    },
    javascript: %{
      module: MykonosBiennaleWeb.Fields.CodeEditor,
      label: "JavaScript",
      mode: "javascript",
      theme: "tomorrow"
    }
  ]
end
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `mode` | string | "html" | Programming language mode (html, css, javascript, json, markdown, elixir, etc.) |
| `theme` | string | "monokai" | Editor theme (monokai, github, tomorrow, etc.) |
| `min_lines` | integer | 10 | Minimum number of visible lines |
| `max_lines` | integer/string | 30 | Maximum number of visible lines (or "Infinity" for unlimited) |
| `font_size` | integer | 14 | Font size in pixels |
| `show_gutter` | boolean | true | Show line numbers in the gutter |
| `show_print_margin` | boolean | false | Show print margin line |
| `placeholder` | string | nil | Placeholder text when field is empty |
| `readonly` | boolean | false | Make the editor read-only |

### Supported Languages

Ace Editor supports many languages out of the box:

- HTML
- CSS
- JavaScript
- JSON
- Markdown
- Elixir
- Python
- Ruby
- PHP
- SQL
- And many more...

### Supported Themes

Popular themes include:

- `monokai` - Dark theme with vibrant colors
- `github` - Light theme similar to GitHub
- `tomorrow` - Clean, minimal theme
- `tomorrow_night` - Dark version of Tomorrow
- `solarized_dark` - Popular dark theme
- `solarized_light` - Popular light theme
- `twilight` - Purple-tinted dark theme
- `chrome` - Clean, professional light theme

For a full list, see the [Ace Editor themes documentation](https://ace.c9.io/build/kitchen-sink.html).

### Advanced Usage

#### Custom Validation

```elixir
content: %{
  module: MykonosBiennaleWeb.Fields.CodeEditor,
  label: "HTML Content",
  mode: "html",
  # Custom validation in your changeset
}
```

Then in your schema:

```elixir
def changeset(page, attrs) do
  page
  |> cast(attrs, [:content])
  |> validate_required([:content])
  |> validate_length(:content, min: 10, max: 50_000)
end
```

#### Conditional Read-only

```elixir
content: %{
  module: MykonosBiennaleWeb.Fields.CodeEditor,
  label: "HTML Content",
  mode: "html",
  readonly: fn assigns -> assigns.live_action == :show end
}
```

#### Dynamic Mode Selection

```elixir
code: %{
  module: MykonosBiennaleWeb.Fields.CodeEditor,
  label: "Code",
  mode: fn assigns ->
    case assigns.item.type do
      "html" -> "html"
      "css" -> "css"
      "javascript" -> "javascript"
      _ -> "text"
    end
  end
}
```

### Keyboard Shortcuts

- **Cmd/Ctrl + S**: Save (submits the form)
- **Tab**: Indent
- **Shift + Tab**: Outdent
- **Cmd/Ctrl + /**: Toggle comment
- **Cmd/Ctrl + F**: Find
- **Cmd/Ctrl + H**: Find and replace
- **Cmd/Ctrl + D**: Select next occurrence
- All standard Ace Editor shortcuts

### Technical Details

#### How It Works

1. The field renders a hidden textarea with the form value
2. An Ace Editor instance is created and synced with the textarea
3. Changes in the editor update the hidden textarea
4. The textarea value is submitted with the form
5. LiveView receives the updated value normally

#### Hook Implementation

The JavaScript hook (`CodeEditor`) handles:
- Editor initialization with configuration
- Syncing editor content with hidden textarea
- Handling LiveView updates
- Cleanup on component destruction

### Troubleshooting

**Editor not appearing:**
- Ensure Ace Editor script is loaded in the root layout
- Check browser console for JavaScript errors

**Syntax highlighting not working:**
- Verify the mode name is correct
- Some modes may need additional Ace modules

**Editor content not saving:**
- Check that the field name matches your schema
- Verify the form is set up correctly with `to_form/2`

**Styling issues:**
- The editor uses Tailwind classes for borders and layout
- You can customize appearance via CSS if needed

### Examples

See the demo at `/admin/pages` (requires authentication) to see the CodeEditor field in action.
