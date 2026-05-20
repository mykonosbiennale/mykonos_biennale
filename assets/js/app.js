// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import EditorHook from "../vendor/ex_editor_hook.js"

const hooks = {
  EditorHook,
  SortableMediaLinks: {
    mounted() {
      this.dragging = null

      this.onDragStart = (e) => {
        const item = e.target.closest("[data-media-id]")
        if (!item) return
        this.dragging = item
        item.classList.add("opacity-60")
        e.dataTransfer.effectAllowed = "move"
        try { e.dataTransfer.setData("text/plain", item.dataset.mediaId) } catch (_) {}
      }

      this.onDragOver = (e) => {
        if (!this.dragging) return
        e.preventDefault()

        const over = e.target.closest("[data-media-id]")
        if (!over || over === this.dragging) return

        const rect = over.getBoundingClientRect()
        const insertAfter = (e.clientY - rect.top) > rect.height / 2
        this.el.insertBefore(this.dragging, insertAfter ? over.nextSibling : over)
      }

      this.onDrop = (e) => {
        if (!this.dragging) return
        e.preventDefault()
        this.pushOrder()
      }

      this.onDragEnd = (_e) => {
        if (!this.dragging) return
        this.dragging.classList.remove("opacity-60")
        this.dragging = null
        this.pushOrder()
      }

      this.el.addEventListener("dragstart", this.onDragStart)
      this.el.addEventListener("dragover", this.onDragOver)
      this.el.addEventListener("drop", this.onDrop)
      this.el.addEventListener("dragend", this.onDragEnd)
    },

    destroyed() {
      this.el.removeEventListener("dragstart", this.onDragStart)
      this.el.removeEventListener("dragover", this.onDragOver)
      this.el.removeEventListener("drop", this.onDrop)
      this.el.removeEventListener("dragend", this.onDragEnd)
    },

    pushOrder() {
      const ids = Array.from(this.el.querySelectorAll("[data-media-id]")).map((el) => el.dataset.mediaId)
      if (ids.length === 0) return
      // Push to the hook element so LiveView routes correctly (including to LiveComponents via phx-target).
      this.pushEventTo(this.el, "reorder_media_links", {media_ids: ids})
    },
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

