import { Controller } from "@hotwired/stimulus"

// A small dropdown menu: click the trigger to open, click outside or press
// Escape to close. Used by the My Teams header actions.
export default class extends Controller {
  static targets = ["trigger", "panel"]

  connect() {
    this.boundOutside = this.clickOutside.bind(this)
    this.boundKey = this.onKey.bind(this)
    document.addEventListener("click", this.boundOutside)
    document.addEventListener("keydown", this.boundKey)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutside)
    document.removeEventListener("keydown", this.boundKey)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.contains("cr-menu-open") ? this.close() : this.open()
  }

  open() {
    this.element.classList.add("cr-menu-open")
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.element.classList.remove("cr-menu-open")
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  onKey(event) {
    if (event.key === "Escape") this.close()
  }
}
