import { Controller } from "@hotwired/stimulus"

// Friendly booking form: start/end time dropdowns plus "90 min / 2 hr /
// Not sure" shortcuts that fill in the end time from the start time.
export default class extends Controller {
  static targets = ["start", "end", "chip"]

  connect() { this.refresh() }

  pick(event) {
    this.setEnd(Number(event.currentTarget.dataset.minutes))
  }

  // Moving the start keeps a 90 min / 2 hr booking the same length.
  startChanged() {
    const length = this.picked
    if (length === 90 || length === 120) this.setEnd(length)
    else this.refresh()
  }

  setEnd(minutes) {
    if (!minutes) {
      this.endTarget.value = ""
    } else {
      const total = this.toMinutes(this.startTarget.value) + minutes
      if (total >= 24 * 60) return
      const value = `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`
      if (![...this.endTarget.options].some(o => o.value === value)) this.endTarget.add(new Option(this.label(total), value))
      this.endTarget.value = value
    }
    this.refresh()
  }

  refresh() {
    const length = this.picked = this.length()
    this.chipTargets.forEach(chip => {
      chip.classList.toggle("is-picked", Number(chip.dataset.minutes) === length)
    })
  }

  // Booked length in minutes, 0 for "Not sure", null for anything else.
  length() {
    if (!this.endTarget.value) return 0
    const diff = this.toMinutes(this.endTarget.value) - this.toMinutes(this.startTarget.value)
    return diff > 0 ? diff : null
  }

  toMinutes(hhmm) {
    const [h, m] = hhmm.split(":").map(Number)
    return h * 60 + m
  }

  label(total) {
    const h = Math.floor(total / 60), m = total % 60
    return `${h % 12 || 12}:${String(m).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`
  }
}
