import { Controller } from "@hotwired/stimulus"

// Standings "spotlight": tap a team row to open that team's panel — roster +
// schedule for your own team, record summary for opponents — right below the
// standings table, no page reload. Mirrors the Tenniscores layout.
export default class extends Controller {
  static targets = ["row", "panel"]

  connect() {
    // Open the user's own team by default, else the first row.
    const initial =
      this.rowTargets.find((r) => r.dataset.standingsSelf === "true") || this.rowTargets[0]
    if (initial) this.show(initial.dataset.standingsId)
  }

  select(event) {
    this.show(event.currentTarget.dataset.standingsId)
  }

  show(id) {
    this.panelTargets.forEach((p) => {
      p.hidden = p.dataset.standingsPanel !== id
    })
    this.rowTargets.forEach((r) => {
      r.classList.toggle("cr-standings-tbl-active", r.dataset.standingsId === id)
    })
  }
}
