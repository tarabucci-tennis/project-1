import { Controller } from "@hotwired/stimulus"

// A small dropdown menu: click the trigger to open, click outside or press
// Escape to close. With hover: true it also opens while a mouse is over it.
// Only one menu is open at a time. Used by the My Teams header actions.
export default class extends Controller {
  static targets = ["trigger", "panel"]
  static values = { hover: Boolean }

  connect() {
    this.boundOutside = this.clickOutside.bind(this)
    this.boundKey = this.onKey.bind(this)
    document.addEventListener("click", this.boundOutside)
    document.addEventListener("keydown", this.boundKey)
    if (this.hoverValue) {
      this.boundEnter = this.mouseEnter.bind(this)
      this.boundLeave = this.mouseLeave.bind(this)
      this.element.addEventListener("mouseenter", this.boundEnter)
      this.element.addEventListener("mouseleave", this.boundLeave)
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutside)
    document.removeEventListener("keydown", this.boundKey)
    if (this.boundEnter) {
      this.element.removeEventListener("mouseenter", this.boundEnter)
      this.element.removeEventListener("mouseleave", this.boundLeave)
    }
    clearTimeout(this.leaveTimer)
  }

  mouseEnter() {
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return
    clearTimeout(this.leaveTimer)
    this.open()
  }

  mouseLeave() {
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return
    this.leaveTimer = setTimeout(() => this.close(), 250)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const isOpen = this.element.classList.contains("cr-menu-open")
    // A mouse already opened it by hovering; a click shouldn't snap it shut.
    if (isOpen && this.hoverValue && window.matchMedia("(hover: hover) and (pointer: fine)").matches) return
    isOpen ? this.close() : this.open()
  }

  open() {
    document.querySelectorAll(".cr-menu.cr-menu-open").forEach(menu => {
      if (menu !== this.element) {
        menu.classList.remove("cr-menu-open")
        menu.querySelector("[aria-expanded]")?.setAttribute("aria-expanded", "false")
      }
    })
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
