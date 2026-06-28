import { Controller } from "@hotwired/stimulus"

// Small segmented toggle (e.g. Schedule | Results). Shows one panel at a time.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() { this.show(0) }

  switch(event) {
    event.preventDefault()
    this.show(this.tabTargets.indexOf(event.currentTarget))
  }

  show(index) {
    this.tabTargets.forEach((tab, i) => tab.classList.toggle("cr-seg-btn-active", i === index))
    this.panelTargets.forEach((panel, i) => { panel.style.display = i === index ? "block" : "none" })
  }
}
