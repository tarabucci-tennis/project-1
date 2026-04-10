import { Controller } from "@hotwired/stimulus"

// Handles the expandable year rows in the match history section.
// Click a year row to expand/collapse the detailed stats.
export default class extends Controller {
  static targets = ["header", "detail"]

  toggle(event) {
    const header = event.currentTarget
    const index = this.headerTargets.indexOf(header)
    const detail = this.detailTargets[index]

    if (!detail) return

    const isOpen = detail.classList.contains("cr-year-detail-open")

    // Close all
    this.detailTargets.forEach((d) => d.classList.remove("cr-year-detail-open"))
    this.headerTargets.forEach((h) => h.classList.remove("cr-year-header-open"))

    // Open clicked one (unless it was already open)
    if (!isOpen) {
      detail.classList.add("cr-year-detail-open")
      header.classList.add("cr-year-header-open")
    }
  }
}
