import { Controller } from "@hotwired/stimulus"

// Suggests places under a "Where" box as you type. The places come with the
// page (clubs, home courts, your earlier friendlies), so nothing is looked up
// elsewhere. Arrow keys move, Enter or Tab picks, Escape closes; a tap or
// click picks too. Picking fills in "Club, street, town".
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { places: Array }

  connect() {
    this.matches = []
    this.active = -1
    this.inputTarget.setAttribute("aria-autocomplete", "list")
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  search() {
    const words = this.inputTarget.value.toLowerCase().split(/[\s,]+/).filter(Boolean)
    if (words.length === 0) return this.close()
    const q = words.join(" ")
    this.matches = this.placesValue
      .map((p) => ({ p, score: this._score(p, words, q) }))
      .filter((m) => m.score > 0)
      .sort((a, b) => b.score - a.score || a.p.name.localeCompare(b.p.name))
      .slice(0, 6)
      .map((m) => m.p)
    // Nothing to offer, or the box already holds exactly the one match.
    if (this.matches.length === 0 ||
        (this.matches.length === 1 && this.matches[0].value.toLowerCase() === this.inputTarget.value.trim().toLowerCase())) {
      return this.close()
    }
    this.active = 0
    this._render()
  }

  key(event) {
    if (this.listTarget.hidden) {
      if (event.key === "ArrowDown") this.search()
      return
    }
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.active = (this.active + step + this.matches.length) % this.matches.length
      this._render()
    } else if (event.key === "Enter" || (event.key === "Tab" && !event.shiftKey)) {
      if (this.active < 0) return
      event.preventDefault()
      this._pick(this.active)
    } else if (event.key === "Escape") {
      this.close()
    }
  }

  // mousedown, not click, so the box doesn't lose focus and close the list first.
  choose(event) {
    event.preventDefault()
    this._pick(Number(event.currentTarget.dataset.index))
  }

  close() {
    this.listTarget.hidden = true
    this.listTarget.innerHTML = ""
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.active = -1
  }

  blur() {
    setTimeout(() => this.close(), 120)
  }

  _pick(index) {
    const place = this.matches[index]
    if (!place) return
    this.inputTarget.value = place.value
    this.close()
  }

  // Every typed word must start a word in the place's name or address.
  // Name matches rank above address-only matches.
  _score(place, words, q) {
    const name = place.name.toLowerCase()
    const hay = `${name} ${(place.address || "").toLowerCase()}`
    const starts = (text, w) => text.startsWith(w) || text.includes(` ${w}`) || text.includes(`,${w}`)
    if (!words.every((w) => starts(hay, w))) return 0
    if (name.startsWith(q)) return 3
    if (words.every((w) => starts(name, w))) return 2
    return 1
  }

  _render() {
    this.listTarget.innerHTML = this.matches.map((p, i) => `
      <li role="option" class="cr-place-opt${i === this.active ? " cr-place-opt-active" : ""}"
          aria-selected="${i === this.active}" data-index="${i}"
          data-action="mousedown->place-suggest#choose">
        <span class="cr-place-name">${escapeHtml(p.name)}</span>
        ${p.address ? `<span class="cr-place-addr">${escapeHtml(p.address)}</span>` : ""}
      </li>`).join("")
    this.listTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }
}

function escapeHtml(str) {
  return String(str ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#039;")
}
