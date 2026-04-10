import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["btnIn", "btnOut", "messageField", "counts", "savedIndicator"]
  static values = { matchId: Number, status: String, message: String }

  connect() {
    this.updateButtonStates()
  }

  markIn() {
    // Already "in" — do nothing (prevents accidental unclick)
    if (this.statusValue === "in") return

    // Switching from "out" to "in" — confirm first
    if (this.statusValue === "out") {
      if (!confirm("Change your availability from Out to In?")) return
    }

    this.statusValue = "in"
    this.save({ status: "in" })
  }

  markOut() {
    // Already "out" — do nothing (prevents accidental unclick)
    if (this.statusValue === "out") return

    // Switching from "in" to "out" — confirm first
    if (this.statusValue === "in") {
      if (!confirm("Change your availability from In to Out?")) return
    }

    this.statusValue = "out"
    this.save({ status: "out" })
  }

  saveMessage(event) {
    if (event.type === "keydown" && event.key !== "Enter") return
    if (event.type === "keydown") event.preventDefault()

    const message = this.messageFieldTarget.value.trim()
    this.messageValue = message
    this.save({ message: message })
  }

  async save(data) {
    this.updateButtonStates()

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(`/matches/${this.matchIdValue}/availability`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify(data)
      })

      if (response.ok) {
        const result = await response.json()
        this.statusValue = result.status
        this.messageValue = result.message || ""
        this.updateButtonStates()
        this.updateCounts(result.counts)
        this.showSaved()
      }
    } catch (error) {
      console.error("Failed to save availability:", error)
    }
  }

  updateButtonStates() {
    if (this.hasBtnInTarget) {
      const isIn = this.statusValue === "in"
      this.btnInTarget.classList.toggle("avail-btn-active", isIn)
      this.btnInTarget.classList.toggle("avail-btn-locked", isIn)
    }
    if (this.hasBtnOutTarget) {
      const isOut = this.statusValue === "out"
      this.btnOutTarget.classList.toggle("avail-btn-active", isOut)
      this.btnOutTarget.classList.toggle("avail-btn-locked", isOut)
    }
  }

  updateCounts(counts) {
    if (!counts || !this.hasCountsTarget) return
    this.countsTarget.innerHTML =
      `<span class="cr-count-in">${counts.in} ✅</span>` +
      `<span class="cr-count-out">${counts.out} ❌</span>` +
      `<span class="cr-count-pending">${counts.no_response} ?</span>`
  }

  showSaved() {
    if (!this.hasSavedIndicatorTarget) return
    const el = this.savedIndicatorTarget
    el.textContent = "Saved!"
    el.classList.add("cr-saved-visible")
    clearTimeout(this._savedTimer)
    this._savedTimer = setTimeout(() => {
      el.classList.remove("cr-saved-visible")
    }, 1500)
  }
}
