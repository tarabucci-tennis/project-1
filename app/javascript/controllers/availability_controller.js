import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["btnIn", "btnOut", "messageField", "counts", "savedIndicator"]
  static values = { matchId: Number, status: String, message: String }

  connect() {
    this.updateButtonStates()
  }

  markIn() {
    if (this.statusValue === "in") {
      this.showConfirm("Remove your response?", "You'll go back to undecided.", () => {
        this.statusValue = "no_response"
        this.save({ status: "no_response" })
      })
      return
    }

    if (this.statusValue === "out") {
      this.showConfirm("Switch to In?", "You're currently marked Out.", () => {
        this.statusValue = "in"
        this.save({ status: "in" })
      })
      return
    }

    this.statusValue = "in"
    this.save({ status: "in" })
  }

  markOut() {
    if (this.statusValue === "out") {
      this.showConfirm("Remove your response?", "You'll go back to undecided.", () => {
        this.statusValue = "no_response"
        this.save({ status: "no_response" })
      })
      return
    }

    if (this.statusValue === "in") {
      this.showConfirm("Switch to Out?", "You're currently marked In.", () => {
        this.statusValue = "out"
        this.save({ status: "out" })
      })
      return
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
    el.textContent = "Saved! 🎾"
    el.classList.add("cr-saved-visible")
    clearTimeout(this._savedTimer)
    this._savedTimer = setTimeout(() => {
      el.classList.remove("cr-saved-visible")
    }, 1500)
  }

  // ── Custom popup ──────────────────────────────────

  showConfirm(title, subtitle, onConfirm) {
    // Remove any existing popup
    document.querySelector(".cr-popup-overlay")?.remove()

    const overlay = document.createElement("div")
    overlay.className = "cr-popup-overlay"
    overlay.innerHTML = `
      <div class="cr-popup">
        <div class="cr-popup-ball">🎾</div>
        <div class="cr-popup-title">${title}</div>
        <div class="cr-popup-sub">${subtitle}</div>
        <div class="cr-popup-buttons">
          <button class="cr-popup-btn cr-popup-cancel">Never mind</button>
          <button class="cr-popup-btn cr-popup-confirm">Yes, change it</button>
        </div>
      </div>
    `

    document.body.appendChild(overlay)

    // Animate in
    requestAnimationFrame(() => overlay.classList.add("cr-popup-visible"))

    const close = () => overlay.remove()

    overlay.querySelector(".cr-popup-cancel").addEventListener("click", close)
    overlay.querySelector(".cr-popup-confirm").addEventListener("click", () => {
      close()
      onConfirm()
    })
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) close()
    })
  }
}
