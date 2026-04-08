import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["btnIn", "btnOut", "messageField", "messageDisplay", "counts"]
  static values = { matchId: Number, status: String, message: String }

  connect() {
    this.updateButtonStates()
  }

  markIn() {
    this.statusValue = "in"
    this.save({ status: "in" })
  }

  markOut() {
    this.statusValue = "out"
    this.save({ status: "out" })
  }

  saveMessage(event) {
    // Save on Enter key or blur
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
      }
    } catch (error) {
      console.error("Failed to save availability:", error)
    }
  }

  updateButtonStates() {
    if (this.hasBtnInTarget) {
      this.btnInTarget.classList.toggle("avail-btn-active", this.statusValue === "in")
    }
    if (this.hasBtnOutTarget) {
      this.btnOutTarget.classList.toggle("avail-btn-active", this.statusValue === "out")
    }
  }

  updateCounts(counts) {
    if (!counts || !this.hasCountsTarget) return
    this.countsTarget.innerHTML =
      `<span class="count-in">${counts.in} ✅</span> · ` +
      `<span class="count-out">${counts.out} ❌</span> · ` +
      `<span class="count-pending">${counts.no_response} ?</span>`
  }
}
