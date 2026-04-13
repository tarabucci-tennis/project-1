import { Controller } from "@hotwired/stimulus"

// Handles tab switching on the team show page.
// Click a tab → shows that section, hides the others.
//
// Also reads a ?tab=<name> query param on page load so other
// places in the app (like the bottom nav bar) can deep-link to a
// specific sub-tab without hardcoding indexes.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // If the URL has ?tab=something, try to match it to a tab by name.
    // We match on the tab's text content (lowercased, substring match),
    // so ?tab=roster → "👥 Roster" → index 2, etc.
    const wanted = new URL(window.location).searchParams.get("tab")
    if (wanted) {
      const needle = wanted.toLowerCase()
      const idx = this.tabTargets.findIndex((el) =>
        el.textContent.trim().toLowerCase().includes(needle)
      )
      if (idx >= 0) {
        this.showTab(idx)
        return
      }
    }
    this.showTab(0)
  }

  switch(event) {
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.showTab(index)
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("cr-subtab-active", i === index)
    })
    this.panelTargets.forEach((panel, i) => {
      panel.style.display = (i === index) ? "block" : "none"
    })
  }
}
