import { Controller } from "@hotwired/stimulus"

// Handles tab switching on the team show page.
// Click a tab → shows that section, hides the others.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Show the first tab by default
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
