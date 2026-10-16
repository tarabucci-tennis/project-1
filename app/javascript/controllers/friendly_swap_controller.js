import { Controller } from "@hotwired/stimulus"

// Friendly lineup: tap one name, then another name in the same set, confirm,
// and the two swap places (saved right away). Tap the same name again to
// cancel. Names in a set marked played can't be swapped: tapping one says so.
export default class extends Controller {
  static targets = ["chip", "form", "setField", "aField", "bField"]

  pick(event) {
    const chip = event.currentTarget
    const setNumber = Number(chip.dataset.set) + 1

    if (chip.dataset.played === "true") {
      this.clear()
      window.alert(`Set ${setNumber} was already played, so it can't be changed.\n\nTap "Undo played" on that set first if you need to fix it.`)
      return
    }

    const first = this.selected
    if (first === chip) {
      this.clear()
      return
    }

    if (first && first.dataset.set === chip.dataset.set) {
      chip.classList.add("is-picked")
      const a = first.textContent.trim()
      const b = chip.textContent.trim()
      if (window.confirm(`Swap ${a} and ${b} in Set ${setNumber}?`)) {
        this.setFieldTarget.value = chip.dataset.set
        this.aFieldTarget.value = first.dataset.pos
        this.bFieldTarget.value = chip.dataset.pos
        this.formTarget.requestSubmit()
      } else {
        chip.classList.remove("is-picked")
        this.clear()
      }
      return
    }

    this.clear()
    this.selected = chip
    chip.classList.add("is-picked")
  }

  clear() {
    if (this.selected) this.selected.classList.remove("is-picked")
    this.selected = null
  }
}
