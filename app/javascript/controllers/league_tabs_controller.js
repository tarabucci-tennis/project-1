import { Controller } from "@hotwired/stimulus"

// Filters the Recent Teams table by league (top-level tab) or by a single
// team (dropdown item). "All" clears the filter.
export default class extends Controller {
  static targets = ["leagueTab", "teamRow"]

  selectLeague(event) {
    const league = event.currentTarget.dataset.league
    this.#activateTab(league)
    this.teamRowTargets.forEach(row => {
      row.hidden = !(league === "all" || row.dataset.league === league)
    })
  }

  selectTeam(event) {
    const { league, teamId } = event.currentTarget.dataset
    this.#activateTab(league)
    this.teamRowTargets.forEach(row => {
      row.hidden = row.dataset.teamId !== teamId
    })
  }

  #activateTab(league) {
    this.leagueTabTargets.forEach(t => {
      t.classList.toggle("active", t.dataset.league === league)
    })
  }
}
