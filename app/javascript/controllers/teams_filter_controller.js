import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "row"]

  connect() {
    this.filter("All")
  }

  select(event) {
    event.preventDefault()
    const type = event.currentTarget.dataset.type
    this.filter(type)
  }

  filter(type) {
    // Update active tab
    this.tabTargets.forEach(tab => {
      if (tab.dataset.type === type) {
        tab.classList.add("tab-active")
      } else {
        tab.classList.remove("tab-active")
      }
    })

    // Filter rows
    this.rowTargets.forEach(row => {
      if (type === "All" || row.dataset.teamType === type) {
        row.style.display = ""
      } else {
        row.style.display = "none"
      }
    })
  }
}
