/**
 * ExEditor JavaScript Hook
 *
 * Provides scroll synchronization and cursor rendering for the double-buffer
 * editor implementation. Works with ExEditorWeb.LiveEditor LiveComponent.
 *
 * Usage:
 *   import EditorHook from "ex_editor/hooks/editor"
 *   let liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: { EditorHook }
 *   })
 */
export default {
  mounted() {
    this.textarea = this.el.querySelector('.ex-editor-textarea')
    this.highlight = this.el.querySelector('.ex-editor-highlight')
    this.lineNumbers = this.el.querySelector('.ex-editor-line-numbers')

    this.cursorEl = null
    this.blinkInterval = null
    this.charWidth = null
    this.lineHeight = null

    this.bindEvents()
    this.setupFakeCursor()
    this.measureFont()
    this.updateCursor()
    this.syncScroll()
  },

  destroyed() {
    this.unbindEvents()
    if (this.cursorEl) {
      this.cursorEl.remove()
    }
    if (this.blinkInterval) {
      clearInterval(this.blinkInterval)
    }
  },

  bindEvents() {
    this._handleScroll = this.handleScroll.bind(this)
    this._handleInput = this.handleInput.bind(this)
    this._handleCursorUpdate = this.handleCursorUpdate.bind(this)
    this._handleResize = this.handleResize.bind(this)

    this.textarea.addEventListener('scroll', this._handleScroll)
    this.textarea.addEventListener('input', this._handleInput)
    this.textarea.addEventListener('click', this._handleCursorUpdate)
    this.textarea.addEventListener('keyup', this._handleCursorUpdate)
    this.textarea.addEventListener('focus', this._handleCursorUpdate)
    this.textarea.addEventListener('blur', this.handleBlur.bind(this))

    window.addEventListener('resize', this._handleResize)

    if (this.lineNumbers) {
      this.lineNumbers.addEventListener('scroll', this._handleScroll)
    }
  },

  unbindEvents() {
    if (this.textarea) {
      this.textarea.removeEventListener('scroll', this._handleScroll)
      this.textarea.removeEventListener('input', this._handleInput)
      this.textarea.removeEventListener('click', this._handleCursorUpdate)
      this.textarea.removeEventListener('keyup', this._handleCursorUpdate)
      this.textarea.removeEventListener('focus', this._handleCursorUpdate)
      this.textarea.removeEventListener('blur', this._handleBlur)
    }

    window.removeEventListener('resize', this._handleResize)

    if (this.lineNumbers) {
      this.lineNumbers.removeEventListener('scroll', this._handleScroll)
    }
  },

  setupFakeCursor() {
    this.cursorEl = document.createElement('div')
    this.cursorEl.className = 'ex-editor-cursor'
    this.highlight.appendChild(this.cursorEl)
    this.startCursorBlink()
  },

  measureFont() {
    const computed = window.getComputedStyle(this.textarea)
    this.lineHeight = parseFloat(computed.lineHeight) || 21
    this.charWidth = this.measureCharWidth(computed.fontSize)
  },

  measureCharWidth(fontSize) {
    const size = parseFloat(fontSize) || 14
    return size * 0.6
  },

  handleScroll() {
    this.syncScroll()
  },

  syncScroll() {
    const scrollTop = this.textarea.scrollTop
    const scrollLeft = this.textarea.scrollLeft

    this.highlight.scrollTop = scrollTop
    this.highlight.scrollLeft = scrollLeft

    if (this.lineNumbers) {
      this.lineNumbers.scrollTop = scrollTop
    }
  },

  handleInput() {
    this.updateCursor()
    this.restartCursorBlink()
  },

  handleCursorUpdate() {
    this.updateCursor()
    this.restartCursorBlink()
  },

  handleBlur() {
    this.stopCursorBlink()
  },

  handleResize() {
    this.measureFont()
    this.updateCursor()
  },

  updateCursor() {
    if (!this.cursorEl) return

    const position = this.textarea.selectionStart
    const coords = this.getCursorCoords(position)

    this.cursorEl.style.top = `${coords.y}px`
    this.cursorEl.style.left = `${coords.x}px`
  },

  getCursorCoords(position) {
    const content = this.textarea.value.substring(0, position)
    const lines = content.split('\n')
    const lineNum = lines.length
    const colNum = lines[lines.length - 1].length

    const y = (lineNum - 1) * this.lineHeight
    const x = colNum * this.charWidth

    return { x, y }
  },

  startCursorBlink() {
    this.cursorEl.style.opacity = '1'
    this.blinkInterval = setInterval(() => {
      const currentOpacity = this.cursorEl.style.opacity
      this.cursorEl.style.opacity = currentOpacity === '0' ? '1' : '0'
    }, 530)
  },

  stopCursorBlink() {
    if (this.blinkInterval) {
      clearInterval(this.blinkInterval)
      this.blinkInterval = null
    }
    if (this.cursorEl) {
      this.cursorEl.style.opacity = '0'
    }
  },

  restartCursorBlink() {
    this.stopCursorBlink()
    this.startCursorBlink()
  }
}