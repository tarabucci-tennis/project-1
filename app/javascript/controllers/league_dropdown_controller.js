import { Controller } from "@hotwired/stimulus"

// Handles click-to-open league dropdowns in the sub-nav.
// On desktop, CSS :hover also opens the dropdown, so this controller
// just handles touch/click behavior and click-outside-to-close.
export default class extends Controller {
  static targets = ["tab"]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const tab = event.currentTarget.closest("[data-league-dropdown-target='tab']")
    const isOpen = tab.classList.contains("cr-league-tab-open")

    this.closeAll()
    if (!isOpen) tab.classList.add("cr-league-tab-open")
  }

  closeAll() {
    this.tabTargets.forEach((t) => t.classList.remove("cr-league-tab-open"))
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeAll()
    }
  }
}
