/**
 * CodeEditor Hook for Phoenix LiveView
 *
 * Integrates Ace Editor for rich code editing experience.
 * Syncs editor content with a hidden form field.
 */

export const CodeEditor = {
  mounted() {
    this.initEditor();
  },

  updated() {
    // Update editor content if the value changed from server
    const newValue = this.el.textContent.trim();
    const currentValue = this.editor.getValue();

    if (newValue !== currentValue) {
      const cursorPosition = this.editor.getCursorPosition();
      this.editor.setValue(newValue, -1);
      this.editor.moveCursorToPosition(cursorPosition);
    }
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy();
      this.editor.container.remove();
    }
  },

  initEditor() {
    // Parse configuration from data attribute
    const config = JSON.parse(this.el.dataset.config || "{}");
    const targetId = this.el.dataset.targetId;
    const targetInput = document.getElementById(targetId);

    if (!targetInput) {
      console.error(`CodeEditor: Target input ${targetId} not found`);
      return;
    }

    // Get initial value from the div content or target input
    const initialValue = this.el.textContent.trim() || targetInput.value || "";

    // Clear the div content since Ace will take over
    this.el.textContent = "";

    // Initialize Ace Editor
    this.editor = ace.edit(this.el);

    // Set editor theme
    this.editor.setTheme(`ace/theme/${config.theme || "monokai"}`);

    // Set editor mode (language)
    const mode = config.mode || "html";
    this.editor.session.setMode(`ace/mode/${mode}`);

    // Configure editor options
    this.editor.setOptions({
      minLines: config.minLines || 10,
      maxLines:
        config.maxLines === "Infinity" ? Infinity : config.maxLines || 30,
      fontSize: `${config.fontSize || 14}px`,
      showGutter: config.showGutter !== false,
      showPrintMargin: config.showPrintMargin === true,
      highlightActiveLine: true,
      enableBasicAutocompletion: true,
      enableLiveAutocompletion: false,
      readOnly: config.readOnly || false,
      wrap: true,
      tabSize: 2,
      useSoftTabs: true,
    });

    // Set initial value
    this.editor.setValue(initialValue, -1); // -1 moves cursor to start

    // Sync editor changes to hidden input
    this.editor.session.on("change", () => {
      const value = this.editor.getValue();
      targetInput.value = value;

      // Trigger change event for LiveView
      targetInput.dispatchEvent(new Event("input", { bubbles: true }));
      this.pushEvent("get_edit", { value: value }, (reply) => {
        console.debug(reply.message);
      });
    });

    // Prevent the editor from capturing all keyboard shortcuts
    this.editor.commands.addCommand({
      name: "save",
      bindKey: { win: "Ctrl-S", mac: "Command-S" },
      exec: () => {
        // Trigger form submission
        const form = this.el.closest("form");
        if (form) {
          form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true }),
          );
        }
      },
    });

    // Focus handling
    this.editor.on("focus", () => {
      this.el.classList.add("ring-2", "ring-primary", "ring-offset-2");
    });

    this.editor.on("blur", () => {
      this.el.classList.remove("ring-2", "ring-primary", "ring-offset-2");
    });
  },
};

export default CodeEditor;
