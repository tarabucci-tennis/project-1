import { Controller } from "@hotwired/stimulus"

// Phones and tablets: the ☰ button slides the left column in over the page;
// tapping outside it, pressing Escape or going to another page closes it.
// On computers the column is always shown and this does nothing.
export default class extends Controller {
  connect() {
    this.boundKey = (event) => { if (event.key === "Escape") this.close() }
    this.boundVisit = () => this.close()
    document.addEventListener("keydown", this.boundKey)
    document.addEventListener("turbo:visit", this.boundVisit)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKey)
    document.removeEventListener("turbo:visit", this.boundVisit)
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    document.body.classList.contains("cr-sb-open") ? this.close() : this.open()
  }

  open() {
    document.body.classList.add("cr-sb-open")
    this.button?.setAttribute("aria-expanded", "true")
  }

  close() {
    document.body.classList.remove("cr-sb-open")
    this.button?.setAttribute("aria-expanded", "false")
  }

  get button() {
    return this.element.querySelector(".cr-sb-burger")
  }
}
