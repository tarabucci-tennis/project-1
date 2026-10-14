import { Controller } from "@hotwired/stimulus"

// Friendly lineup: tap one name, then another name in the same set, and the
// two swap places (saved right away). Tap the same name again to cancel.
export default class extends Controller {
  static targets = ["chip", "form", "setField", "aField", "bField"]

  pick(event) {
    const chip = event.currentTarget
    const first = this.selected

    if (first === chip) {
      chip.classList.remove("is-picked")
      this.selected = null
      return
    }

    if (first && first.dataset.set === chip.dataset.set) {
      chip.classList.add("is-picked")
      this.setFieldTarget.value = chip.dataset.set
      this.aFieldTarget.value = first.dataset.pos
      this.bFieldTarget.value = chip.dataset.pos
      this.formTarget.requestSubmit()
      return
    }

    if (first) first.classList.remove("is-picked")
    this.selected = chip
    chip.classList.add("is-picked")
  }
}
