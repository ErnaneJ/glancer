import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  create(event) {
    event.preventDefault();

    fetch(event.currentTarget.href || event.target.href, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken,
      }
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
    .catch(() => this.toast("Failed to create chat", "error"));
  }

  select(event) {
    event.preventDefault();
    const chatId = event.currentTarget.dataset.chatId;
    this.closeSidebar();
    Turbo.visit(`/glancer/chats/${chatId}`);
  }

  copy(event) {
    const button = event.currentTarget;
    const content = button.dataset.message;

    navigator.clipboard.writeText(content)
      .then(() => {
        this.toast("Copied to clipboard", "success");
      })
      .catch(() => {
        this.toast("Copy failed", "error");
      });
  }

  toggleTheme() {
    const isDark = document.documentElement.classList.toggle("dark");
    localStorage.setItem("glancer-theme", isDark ? "dark" : "light");
  }

  openSidebar() {
    const sidebar = document.getElementById("sidebar");
    const overlay = document.getElementById("sidebar-overlay");
    sidebar?.classList.remove("-translate-x-full");
    overlay?.classList.remove("hidden");
    document.body.style.overflow = "hidden";
  }

  closeSidebar() {
    const sidebar = document.getElementById("sidebar");
    const overlay = document.getElementById("sidebar-overlay");
    sidebar?.classList.add("-translate-x-full");
    overlay?.classList.add("hidden");
    document.body.style.overflow = "";
  }

  toast(message, type = "info") {
    document.dispatchEvent(new CustomEvent("glancer:toast", { detail: { message, type } }));
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']")?.content ?? "";
  }
}
