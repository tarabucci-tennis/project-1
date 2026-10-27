import { Controller } from "@hotwired/stimulus"

// Set Lineup: tap a player's name, then tap "Put … here" on the line you
// want her on. It just sets that line's dropdown (the dropdowns still work
// on their own). A player can only be on one line, so placing her moves her
// off any other line. Each name shows the line she's on.
export default class extends Controller {
  static targets = ["chip", "select", "spot"]

  connect() {
    this.picked = null
    this.refresh()
  }

  pick(event) {
    const id = event.currentTarget.dataset.userId
    this.picked = this.picked === id ? null : id
    this.refresh()
  }

  place(event) {
    if (!this.picked) return
    const select = event.currentTarget.closest(".cr-lineup-slot-row").querySelector("select")
    this.selectTargets.forEach((s) => {
      if (s !== select && s.value === this.picked) this._set(s, "")
    })
    this._set(select, this.picked)
    this.picked = null
    this.refresh()
  }

  // × next to a spot: take that player off this line.
  clear(event) {
    this._set(event.currentTarget.closest(".cr-lineup-slot-row").querySelector("select"), "")
    this.refresh()
  }

  // Clear lineup: empty every spot (saved only when the captain saves).
  clearAll() {
    if (!window.confirm("Take every player off this lineup? Nothing is saved until you press Save Draft or Post Lineup.")) return
    this.selectTargets.forEach((s) => this._set(s, ""))
    this.picked = null
    this.refresh()
  }

  // A dropdown changed by hand: keep the names' line tags in step.
  changed() {
    this.refresh()
  }

  refresh() {
    this.element.classList.toggle("is-picking", !!this.picked)
    const pickedChip = this.chipTargets.find((c) => c.dataset.userId === this.picked)
    const first = pickedChip ? pickedChip.dataset.first : ""

    this.chipTargets.forEach((chip) => {
      chip.classList.toggle("is-picked", chip.dataset.userId === this.picked)
      chip.setAttribute("aria-pressed", chip.dataset.userId === this.picked)
      const on = this.selectTargets.find((s) => s.value === chip.dataset.userId)
      const tag = chip.querySelector(".cr-lp-line")
      tag.textContent = on ? on.dataset.line : ""
      tag.hidden = !on
    })
    this.spotTargets.forEach((spot) => {
      spot.hidden = !this.picked
      spot.textContent = `Put ${first} here`
    })
  }

  _set(select, value) {
    select.value = value
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
