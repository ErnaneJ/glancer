import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.addEventListener("glancer:toast", this.handleToast.bind(this));
  }

  disconnect() {
    document.removeEventListener("glancer:toast", this.handleToast.bind(this));
  }

  handleToast(event) {
    const { message, type = "info" } = event.detail;
    this.show(message, type);
  }

  show(message, type = "info") {
    const toast = document.createElement("div");

    const colors = {
      success: "bg-green-600 text-white",
      error:   "bg-red-600 text-white",
      info:    "bg-gray-800 dark:bg-gray-700 text-white",
    };

    const icons = {
      success: "#icon-check",
      error:   "#icon-x",
      info:    "#icon-info",
    };

    toast.className = [
      "pointer-events-auto flex items-center gap-2.5 px-4 py-3 rounded-xl shadow-lg text-sm font-medium",
      "translate-y-2 opacity-0 transition-all duration-200 ease-out",
      colors[type] || colors.info,
    ].join(" ");

    toast.innerHTML = `
      <svg class="w-4 h-4 flex-shrink-0" aria-hidden="true"><use href="${icons[type] || icons.info}"/></svg>
      <span>${this.escapeHtml(message)}</span>
    `;

    this.element.appendChild(toast);

    // Animate in
    requestAnimationFrame(() => {
      toast.classList.remove("translate-y-2", "opacity-0");
    });

    // Auto-dismiss after 4s
    setTimeout(() => {
      toast.classList.add("opacity-0", "translate-y-2");
      toast.addEventListener("transitionend", () => toast.remove(), { once: true });
    }, 4000);
  }

  escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }
}
