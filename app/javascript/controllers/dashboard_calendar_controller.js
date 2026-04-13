import { Controller } from "@hotwired/stimulus"

// Powers the clickable month calendar on the My Teams home page. Each day
// button carries a JSON payload with its matches + team events for that
// date. Clicking opens a modal showing them, and (for captains/co-captains
// of at least one team) a form to add a practice/clinic/friendly.
export default class extends Controller {
  static targets = [
    "modal", "title", "body",
    "addWrap", "form", "formDate", "formTeam",
    "captainNote"
  ]
  static values  = { teams: Array }

  connect() {
    this._boundKey = this._onKeyDown.bind(this)
    document.addEventListener("keydown", this._boundKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this._boundKey)
  }

  open(event) {
    event.preventDefault()
    const btn = event.currentTarget
    let payload = {}
    try {
      const raw = btn.getAttribute("data-dashboard-calendar-payload-param") || "{}"
      payload = JSON.parse(raw)
    } catch (_e) {
      payload = {}
    }

    this.titleTarget.textContent = payload.label || "Day"
    this.bodyTarget.innerHTML    = this._renderItems(payload)

    // Is there at least one team we can manage? If so, show the Add form.
    const manageableTeams = (this.teamsValue || []).filter(t => t.can_manage)
    if (manageableTeams.length > 0) {
      this.addWrapTarget.style.display = ""
      this.captainNoteTarget.style.display = "none"
      if (this.hasFormDateTarget) {
        this.formDateTarget.value = payload.date || ""
      }
      if (this.hasFormTarget && payload.date) {
        // Point the form at /teams/:team_id/events for the currently selected
        // team in the dropdown. We rewrite action on submit as well, since
        // the team can change.
        this._updateFormAction()
      }
    } else {
      this.addWrapTarget.style.display = "none"
      this.captainNoteTarget.style.display = ""
    }

    this.modalTarget.classList.add("cr-dash-cal-modal-open")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.modalTarget.classList.remove("cr-dash-cal-modal-open")
    document.body.style.overflow = ""
  }

  closeBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  // Rewrite the form's action attribute to the currently selected team
  // just before submit, so Rails routes the POST to the right
  // /teams/:team_id/events endpoint.
  submitForm(event) {
    this._updateFormAction()
    // Let the browser handle the actual POST normally.
  }

  _updateFormAction() {
    if (!this.hasFormTarget || !this.hasFormTeamTarget) return
    const teamId = this.formTeamTarget.value
    if (!teamId) return
    this.formTarget.action = `/teams/${teamId}/events`
  }

  _onKeyDown(event) {
    if (event.key === "Escape" && this.modalTarget.classList.contains("cr-dash-cal-modal-open")) {
      this.close()
    }
  }

  _renderItems(payload) {
    const matches = payload.matches || []
    const events  = payload.events  || []

    if (matches.length === 0 && events.length === 0) {
      return `<p class="cr-dash-cal-modal-empty">Nothing scheduled this day yet.</p>`
    }

    const parts = []

    matches.forEach((m) => {
      const time = m.time ? `<div class="cr-dash-cal-item-meta">${escapeHtml(m.time)}</div>` : ""
      const loc  = m.location ? `<div class="cr-dash-cal-item-meta">${escapeHtml(m.location)}</div>` : ""
      parts.push(`
        <a class="cr-dash-cal-item cr-dash-cal-item-match" href="${escapeHtml(m.url)}">
          <div class="cr-dash-cal-item-row">
            <span class="cr-dash-cal-item-kind">Match</span>
            <span class="cr-dash-cal-item-team">${escapeHtml(m.team || "")}</span>
          </div>
          <div class="cr-dash-cal-item-title">vs. ${escapeHtml(m.opponent || "TBD")}</div>
          ${time}
          ${loc}
          <div class="cr-dash-cal-item-view">View match details →</div>
        </a>
      `)
    })

    events.forEach((e) => {
      const time = e.time ? `<div class="cr-dash-cal-item-meta">${escapeHtml(e.time)}</div>` : ""
      const loc  = e.location ? `<div class="cr-dash-cal-item-meta">${escapeHtml(e.location)}</div>` : ""
      parts.push(`
        <div class="cr-dash-cal-item cr-dash-cal-item-${escapeHtml(e.kind || "event")}">
          <div class="cr-dash-cal-item-row">
            <span class="cr-dash-cal-item-kind">${escapeHtml(e.kind_label || "Event")}</span>
            <span class="cr-dash-cal-item-team">${escapeHtml(e.team || "")}</span>
          </div>
          <div class="cr-dash-cal-item-title">${escapeHtml(e.title || "")}</div>
          ${time}
          ${loc}
        </div>
      `)
    })

    return parts.join("")
  }
}

function escapeHtml(str) {
  if (str == null) return ""
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}
