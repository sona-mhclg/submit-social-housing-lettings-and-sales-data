import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const affectedField = this.element.dataset.target;
    const targetQuestion = affectedField.split("case-log-")[1].split("-field")[0]
    const div = document.getElementById(targetQuestion + "_div");
    div.style.display = "block";
  }

  calculateFields() {
    const affectedField = this.element.dataset.target;
    const fieldsToAdd = JSON.parse(this.element.dataset.calculated).map(x => `case-log-${x.replaceAll("_","-")}-field`);
    const valuesToAdd = fieldsToAdd.map(x => getFieldValue(x)).filter(x => x);
    const newValue =  valuesToAdd.map(x => parseFloat(x)).reduce((a, b) => a + b, 0).toFixed(2);
    const elementToUpdate = document.getElementById(affectedField);
    elementToUpdate.value = newValue;
  }
  }
  let getFieldValue = (field) => {
    const elementFieldToAdd= document.getElementById(field)
    if (elementFieldToAdd) {
      return elementFieldToAdd.value
    }
     return document.getElementById(`${field}-error`).value
}

