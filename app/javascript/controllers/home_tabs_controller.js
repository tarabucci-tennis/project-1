import { Controller } from "@hotwired/stimulus"

// Tabbed dashboard on the My Teams home page: Standings / Calendar / Coming Up.
// Unlike team-tabs (which hides tabs and stacks panels on mobile), these tabs
// stay tab-like on every screen size — switching is the whole point here.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const wanted = new URL(window.location).searchParams.get("tab")
    if (wanted) {
      const idx = this.tabTargets.findIndex((el) =>
        el.textContent.trim().toLowerCase().includes(wanted.toLowerCase())
      )
      if (idx >= 0) { this.showTab(idx); return }
    }
    this.showTab(0)
  }

  switch(event) {
    event.preventDefault()
    this.showTab(this.tabTargets.indexOf(event.currentTarget))
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => tab.classList.toggle("cr-home-tab-active", i === index))
    this.panelTargets.forEach((panel, i) => { panel.style.display = i === index ? "block" : "none" })
  }
}
