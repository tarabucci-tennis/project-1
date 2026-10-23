import { Controller } from "@hotwired/stimulus"

// Powers the clickable month calendar on the My Teams home page. Each day
// button carries a JSON payload with its matches + team events for that
// date. Clicking opens a modal showing them, and (for captains/co-captains
// of at least one team) a form to add a friendly or clinic.
export default class extends Controller {
  static targets = [
    "modal", "title", "body",
    "addWrap", "form", "formDate", "formTeam",
    "captainNote", "hover", "hoverTitle", "hoverBody"
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
    // With a mouse, clicking an event's name inside the day opens that event.
    const chip = event.target.closest("[data-url]")
    if (chip && this._canHover()) return this._visit(chip.dataset.url)
    this._hideHover()
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

  // Mouse only: hovering a day with events shows its schedule beside it.
  hoverIn(event) {
    if (!this._canHover() || !this.hasHoverTarget) return
    clearTimeout(this._hideTimer)
    const btn = event.currentTarget
    const payload = this._payload(btn)
    const count = (payload.matches || []).length + (payload.events || []).length + (payload.friendlies || []).length
    // An empty day only starts the normal close delay, so brushing past it on
    // the way into the pop-up doesn't snap the pop-up shut.
    if (count === 0) return this.hoverOut()
    clearTimeout(this._showTimer)
    this._showTimer = setTimeout(() => this._showHover(btn, payload), 150)
  }

  hoverKeep() {
    clearTimeout(this._hideTimer)
  }

  hoverOut() {
    clearTimeout(this._showTimer)
    clearTimeout(this._hideTimer)
    this._hideTimer = setTimeout(() => this._hideHover(), 200)
  }

  _showHover(btn, payload) {
    const box = this.hoverTarget
    this.hoverTitleTarget.textContent = payload.label || ""
    this.hoverBodyTarget.innerHTML = this._renderItems(payload)
    box.hidden = false
    // Place it beside the day (right side, or left if there's no room), inside the
    // calendar. It slightly overlaps the day so the mouse goes straight into it
    // without crossing a neighbouring day.
    const wrap = box.offsetParent.getBoundingClientRect()
    const cell = btn.getBoundingClientRect()
    const overlap = 6
    let left = cell.right - wrap.left - overlap
    if (cell.right - overlap + box.offsetWidth > window.innerWidth - 8) left = cell.left - wrap.left + overlap - box.offsetWidth
    left = Math.max(0, left)
    let top = cell.top - wrap.top
    const maxTop = window.innerHeight - wrap.top - box.offsetHeight - 8
    top = Math.max(0, Math.min(top, maxTop))
    box.style.left = `${left}px`
    box.style.top = `${top}px`
  }

  _hideHover() {
    if (this.hasHoverTarget) this.hoverTarget.hidden = true
  }

  _canHover() {
    return window.matchMedia("(hover: hover) and (pointer: fine)").matches
  }

  _visit(url) {
    if (window.Turbo) window.Turbo.visit(url)
    else window.location.href = url
  }

  _payload(btn) {
    try {
      return JSON.parse(btn.getAttribute("data-dashboard-calendar-payload-param") || "{}")
    } catch (_e) {
      return {}
    }
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
    const friendlies = payload.friendlies || []

    if (matches.length === 0 && events.length === 0 && friendlies.length === 0) {
      return `<p class="cr-dash-cal-modal-empty">Nothing scheduled this day yet.</p>`
    }

    const parts = []

    matches.forEach((m) => {
      const time = m.time ? `<div class="cr-dash-cal-item-meta">${escapeHtml(m.time)}</div>` : ""
      const loc  = m.location ? `<div class="cr-dash-cal-item-meta">${escapeHtml(m.location)}</div>` : ""
      // The whole card opens the match; the team name is its own link.
      parts.push(`
        <div class="cr-dash-cal-item cr-dash-cal-item-match">
          <div class="cr-dash-cal-item-row">
            <span class="cr-dash-cal-item-kind">Match</span>
            ${teamLink(m)}
          </div>
          <a class="cr-dash-cal-item-title cr-dash-cal-item-stretch" href="${escapeHtml(m.url)}">vs. ${escapeHtml(m.opponent || "TBD")}</a>
          ${time}
          ${loc}
          <div class="cr-dash-cal-item-view">View match details →</div>
        </div>
      `)
    })

    events.forEach((e) => {
      const time = e.time ? `<div class="cr-dash-cal-item-meta">${escapeHtml(e.time)}</div>` : ""
      const loc  = e.location ? `<div class="cr-dash-cal-item-meta">${escapeHtml(e.location)}</div>` : ""
      parts.push(`
        <div class="cr-dash-cal-item cr-dash-cal-item-${escapeHtml(e.kind || "event")}">
          <div class="cr-dash-cal-item-row">
            <span class="cr-dash-cal-item-kind">${escapeHtml(e.kind_label || "Event")}</span>
            ${teamLink(e)}
          </div>
          <div class="cr-dash-cal-item-title">${escapeHtml(e.title || "")}</div>
          ${time}
          ${loc}
        </div>
      `)
    })

    friendlies.forEach((f) => {
      const loc = f.location ? `<div class="cr-dash-cal-item-meta">${escapeHtml(f.location)}</div>` : ""
      parts.push(`
        <a class="cr-dash-cal-item cr-dash-cal-item-friendly cr-dash-cal-item-friendly-link" href="${escapeHtml(f.url)}">
          <div class="cr-dash-cal-item-row">
            <span class="cr-dash-cal-item-kind">Friendly</span>
            <span class="cr-dash-cal-item-team">${escapeHtml(f.spots || "")}</span>
          </div>
          <div class="cr-dash-cal-item-title">${escapeHtml(f.title || "Friendly")}</div>
          <div class="cr-dash-cal-item-meta">${escapeHtml(f.time || "")}</div>
          ${loc}
          <div class="cr-dash-cal-item-view">See who's playing →</div>
        </a>
      `)
    })

    return parts.join("")
  }
}

// The team name in a calendar item, linking to the team page when known.
function teamLink(item) {
  if (!item.team) return ""
  if (!item.team_url) return `<span class="cr-dash-cal-item-team">${escapeHtml(item.team)}</span>`
  return `<a class="cr-dash-cal-item-team cr-dash-cal-item-teamlink" href="${escapeHtml(item.team_url)}">${escapeHtml(item.team)}</a>`
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
