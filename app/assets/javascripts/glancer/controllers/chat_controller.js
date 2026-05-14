import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Restore desktop sidebar state from localStorage
    const sidebarState = localStorage.getItem("glancer-sidebar-desktop");
    if (sidebarState === "closed") {
      this._collapseSidebar(false);
    }
  }

  create(event) {
    event.preventDefault();
    Turbo.visit(event.currentTarget.href);
  }

  select(event) {
    event.preventDefault();
    const chatId = event.currentTarget.dataset.chatId;
    this.closeSidebar();
    Turbo.visit(`/glancer/chats/${chatId}`);
  }

  copy(event) {
    const content = event.currentTarget.dataset.message;
    navigator.clipboard.writeText(content)
      .then(() => this.toast("Copiado", "success"))
      .catch(() => this.toast("Falha ao copiar", "error"));
  }

  toggleTheme() {
    const isDark = document.documentElement.classList.toggle("dark");
    localStorage.setItem("glancer-theme", isDark ? "dark" : "light");
  }

  // ── Mobile sidebar ───────────────────────────────────────────────────────

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

  // ── Desktop sidebar toggle ───────────────────────────────────────────────

  toggleDesktopSidebar() {
    const sidebar = document.getElementById("sidebar");
    if (!sidebar) return;

    const isCollapsed = sidebar.classList.contains("lg:w-0");
    if (isCollapsed) {
      this._expandSidebar();
    } else {
      this._collapseSidebar(true);
    }
  }

  _collapseSidebar(persist = true) {
    const sidebar = document.getElementById("sidebar");
    const expandBtn = document.getElementById("sidebar-expand-btn");
    sidebar?.classList.add("lg:w-0", "lg:overflow-hidden", "lg:min-w-0");
    sidebar?.classList.remove("lg:w-64", "lg:translate-x-0");
    if (expandBtn) {
      expandBtn.classList.remove("hidden");
      expandBtn.removeAttribute("aria-hidden");
    }
    if (persist) localStorage.setItem("glancer-sidebar-desktop", "closed");
  }

  _expandSidebar() {
    const sidebar = document.getElementById("sidebar");
    const expandBtn = document.getElementById("sidebar-expand-btn");
    sidebar?.classList.remove("lg:w-0", "lg:overflow-hidden", "lg:min-w-0");
    sidebar?.classList.add("lg:w-64", "lg:translate-x-0");
    if (expandBtn) {
      expandBtn.classList.add("hidden");
      expandBtn.setAttribute("aria-hidden", "true");
    }
    localStorage.setItem("glancer-sidebar-desktop", "open");
  }

  // ── Toast ────────────────────────────────────────────────────────────────

  toast(message, type = "info") {
    document.dispatchEvent(new CustomEvent("glancer:toast", { detail: { message, type } }));
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']")?.content ?? "";
  }
}
