import { Controller } from "@hotwired/stimulus"

// Enter Results: as scores are typed, each line's W/L and the team result
// fill themselves in by the league's rule. Mirrors app/services/line_scoring.rb
// (the server applies the same rule if nothing was picked). Anything the
// player taps by hand is left alone for the rest of the visit.
export default class extends Controller {
  static targets = ["line", "matchResult", "summary", "barSummary"]
  static values = { mode: String } // "sets" | "games" | "either"

  connect() {
    this.touchedLines = new Set()
    this.matchTouched = false
    this.updateSummary()
  }

  scoreChanged(event) {
    const box = event.target
    box.value = box.value.replace(/\D/g, "").slice(0, 2)
    this.advance(box)
    const line = box.closest("[data-score-entry-target='line']")
    if (line && !this.touchedLines.has(line)) this.setLineResult(line, this.lineResult(this.setsOf(line)))
    this.refreshMatch()
  }

  // Typing moves to the next box, so "6 3 6 4" goes in without tapping
  // between boxes. A game score is one digit; only the third-set box waits
  // after a "1" (a match tiebreak can reach 10), and two digits always move on.
  advance(box) {
    const v = box.value
    if (v === "") return
    const set = box.dataset.set
    if (v.length === 1 && set === "3" && v === "1") return
    const line = box.closest("[data-score-entry-target='line']")
    const boxes = Array.from(line.querySelectorAll("input[data-set]"))
    const next = boxes[boxes.indexOf(box) + 1]
    if (next) { next.focus(); next.select() }
  }

  touchLine(event) {
    this.touchedLines.add(event.target.closest("[data-score-entry-target='line']"))
    this.refreshMatch()
  }

  touchMatch() {
    this.matchTouched = true
    this.updateSummary()
  }

  // ── rules (same as LineScoring) ──
  setsOf(line) {
    const sets = []
    for (let n = 1; n <= 3; n++) {
      const o = line.querySelector(`[data-set='${n}'][data-side='ours']`)?.value
      const t = line.querySelector(`[data-set='${n}'][data-side='theirs']`)?.value
      if (o === "" && t === "") continue
      if (o === undefined || t === undefined) continue
      sets.push([parseInt(o || "0", 10), parseInt(t || "0", 10)])
    }
    return sets
  }

  compare(a, b) { return a > b ? "win" : (b > a ? "loss" : null) }

  lineResult(sets) {
    if (sets.length === 0) return null
    const bySets = this.compare(sets.filter(([o, t]) => o > t).length, sets.filter(([o, t]) => t > o).length)
    const byGames = this.compare(sets.reduce((s, [o]) => s + o, 0), sets.reduce((s, [, t]) => s + t, 0))
    if (this.modeValue === "sets") return bySets
    if (this.modeValue === "games") return byGames
    return bySets === byGames ? bySets : null
  }

  lineState(line) {
    const checked = line.querySelector("input[data-line-result]:checked")
    return { result: checked ? checked.dataset.lineResult : null, sets: this.setsOf(line) }
  }

  matchResult(lines) {
    const decided = lines.filter(l => l.result)
    if (decided.length === 0) return null
    if (lines.some(l => l.sets.length > 0 && !l.result)) return null
    const byLines = this.compare(decided.filter(l => l.result === "win").length, decided.filter(l => l.result === "loss").length)
    if (byLines) return byLines
    if (this.modeValue === "sets") return null
    if (this.modeValue === "games") {
      const all = lines.flatMap(l => l.sets)
      const byGames = this.compare(all.reduce((s, [o]) => s + o, 0), all.reduce((s, [, t]) => s + t, 0))
      if (byGames) return byGames
    }
    return "tie"
  }

  // ── page updates ──
  setLineResult(line, result) {
    line.querySelectorAll("input[data-line-result]").forEach(r => { r.checked = (r.dataset.lineResult === result) })
  }

  refreshMatch() {
    if (!this.matchTouched) {
      const result = this.matchResult(this.lineTargets.map(l => this.lineState(l)))
      this.matchResultTargets.forEach(r => { r.checked = (r.value === result) })
    }
    this.updateSummary()
  }

  updateSummary() {
    const states = this.lineTargets.map(l => this.lineState(l))
    // One-line page (a player's own line): talk about her line only.
    if (!this.hasMatchResultTarget) {
      const r = states[0] && states[0].result
      if (this.hasBarSummaryTarget) this.barSummaryTarget.textContent = r ? `Your line: ${r === "win" ? "Win" : "Loss"}` : ""
      return
    }
    const won = states.filter(l => l.result === "win").length
    const lost = states.filter(l => l.result === "loss").length
    const picked = this.matchResultTargets.find(r => r.checked)
    const label = picked ? { win: "Win", loss: "Loss", tie: "Tie" }[picked.value] : "pick a result"
    const text = (won + lost) > 0 ? `Lines ${won}–${lost} · ${label}` : ""
    if (this.hasBarSummaryTarget) this.barSummaryTarget.textContent = text
    if (this.hasSummaryTarget && text) {
      this.summaryTarget.textContent = `${text}. Fills in from the line scores; tap to change it.`
    }
  }
}
