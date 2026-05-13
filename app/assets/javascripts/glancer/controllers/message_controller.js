import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form", "submitBtn", "charCount", "runBtn", "downloadBtn", "resultsContainer"]

  connect() {
    if (this.hasInputTarget) {
      this.autoResize();
      this.updateCharCount();
      this.scrollToBottom();
    }
  }

  // ── Form submission ──────────────────────────────────────────────────────────

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.ctrlKey && !event.metaKey) {
      event.preventDefault();
      this.formTarget.requestSubmit();
    }
  }

  async submit(event) {
    event.preventDefault();

    const input = this.inputTarget;
    const content = input?.value?.trim();
    if (!content) return;

    this.setSubmitting(true);
    const formData = new FormData(this.formTarget);
    input.value = "";
    this.autoResize();
    this.updateCharCount();

    this.showThinking();

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: formData,
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        }
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      this.scrollToBottom();
      await this.typewriterEffect();
      this.highlightCode();

    } catch (error) {
      this.removeThinking();
      this.toast("Failed to send message", "error");
    } finally {
      this.setSubmitting(false);
    }
  }

  // ── SQL execution ─────────────────────────────────────────────────────────

  async runQuery(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const messageId = btn.dataset.messageId;
    const container = this.resultsContainerTarget;

    btn.disabled = true;
    container.innerHTML = `
      <div class="flex items-center gap-2 px-4 py-3 text-xs text-gray-400">
        <span class="inline-block w-3 h-3 rounded-full border-2 border-gray-300 border-t-primary-500 animate-spin"></span>
        Executing query…
      </div>
    `;

    try {
      const response = await fetch(`/glancer/messages/${messageId}/run_sql`, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        }
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);
      btn.querySelector("span")?.replaceWith(Object.assign(document.createElement("span"), { textContent: "Re-run" }));

    } catch (error) {
      container.innerHTML = `<div class="px-4 py-3 text-xs text-red-500">Error: ${error.message}</div>`;
    } finally {
      btn.disabled = false;
    }
  }

  exportToCSV(event) {
    event.preventDefault();

    const table = this.resultsContainerTarget?.querySelector("table");
    if (!table) {
      this.toast("No data to export", "info");
      return;
    }

    const rows = Array.from(table.querySelectorAll("tr"));
    const csv = rows.map(row =>
      Array.from(row.querySelectorAll("th, td"))
        .map(cell => `"${cell.innerText.trim().replace(/"/g, '""')}"`)
        .join(",")
    ).join("\r\n");

    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `glancer_${new Date().toISOString().slice(0, 19).replace(/:/g, "-")}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    this.toast("CSV exported", "success");
  }

  // ── Message info panel ───────────────────────────────────────────────────

  async openMessageInfo(event) {
    const messageId = event.currentTarget.dataset.messageId;

    try {
      const response = await fetch(`/glancer/messages/${messageId}/info`, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        }
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      requestAnimationFrame(() => {
        setTimeout(() => {
          document.getElementById("message-info--content")?.classList.remove("translate-x-full");
          this.highlightCode();
        }, 50);
      });

    } catch (error) {
      this.toast("Could not load message details", "error");
    }
  }

  closeMessageInfo() {
    const panel = document.getElementById("message-info--content");
    if (!panel) return;

    panel.classList.add("translate-x-full");
    panel.addEventListener("transitionend", () => {
      document.getElementById("message-info--area")?.remove();
    }, { once: true });
  }

  stopPropagation(event) {
    event.stopPropagation();
  }

  // ── UX helpers ──────────────────────────────────────────────────────────

  autoResize() {
    if (!this.hasInputTarget) return;
    const el = this.inputTarget;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
  }

  updateCharCount() {
    if (!this.hasInputTarget || !this.hasCharCountTarget) return;
    const len = this.inputTarget.value.length;
    this.charCountTarget.textContent = `${len} / 2000`;
    this.charCountTarget.classList.toggle("text-red-400", len > 1800);
  }

  scrollToBottom() {
    const el = document.getElementById("chat-messages");
    if (el) el.scrollTop = el.scrollHeight;
  }

  setSubmitting(loading) {
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = loading;
  }

  // ── Thinking indicator ───────────────────────────────────────────────────

  showThinking() {
    this.removeThinking();

    const el = document.createElement("div");
    el.id = "thinking-indicator";
    el.className = "flex items-start gap-3";
    el.innerHTML = `
      <div class="flex-shrink-0 w-7 h-7 rounded-lg bg-primary-100 dark:bg-primary-950 flex items-center justify-center" aria-hidden="true">
        <svg class="w-3.5 h-3.5 text-primary-600 dark:text-primary-400"><use href="#icon-database"/></svg>
      </div>
      <div class="flex items-center gap-1.5 mt-2" aria-label="Glancer is thinking" role="status">
        <span class="w-2 h-2 rounded-full bg-primary-400 dark:bg-primary-500 animate-bounce" style="animation-delay:0ms"></span>
        <span class="w-2 h-2 rounded-full bg-primary-400 dark:bg-primary-500 animate-bounce" style="animation-delay:150ms"></span>
        <span class="w-2 h-2 rounded-full bg-primary-400 dark:bg-primary-500 animate-bounce" style="animation-delay:300ms"></span>
      </div>
    `;

    document.getElementById("chat-messages")?.appendChild(el);
    this.scrollToBottom();
  }

  removeThinking() {
    document.getElementById("thinking-indicator")?.remove();
  }

  // ── Typewriter effect ─────────────────────────────────────────────────────

  async typewriterEffect() {
    const el = document.querySelector(".message.assistant:last-of-type .message-content");
    if (!el) return;

    const html = el.innerHTML;
    el.innerHTML = '<span class="cursor-blink" aria-hidden="true">|</span>';

    const append = async (node, target) => {
      if (node.nodeType === Node.TEXT_NODE) {
        for (const ch of node.textContent) {
          target.append(ch);
          await new Promise(r => setTimeout(r, 10));
        }
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        const clone = node.cloneNode(false);
        target.appendChild(clone);
        for (const child of node.childNodes) await append(child, clone);
      }
    };

    const tmp = document.createElement("div");
    tmp.innerHTML = html;
    const cursor = Object.assign(document.createElement("span"), { className: "cursor-blink", textContent: "|", ariaHidden: "true" });

    for (const node of tmp.childNodes) {
      el.lastChild?.classList?.contains("cursor-blink") && el.removeChild(el.lastChild);
      await append(node, el);
      el.appendChild(cursor);
    }

    el.innerHTML = html;
    this.highlightCode();
  }

  // ── Syntax highlighting ───────────────────────────────────────────────────

  highlightCode() {
    if (window.Prism) {
      setTimeout(() => Prism.highlightAll(), 50);
    }
  }

  // ── Toast ────────────────────────────────────────────────────────────────

  toast(message, type = "info") {
    document.dispatchEvent(new CustomEvent("glancer:toast", { detail: { message, type } }));
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']")?.content ?? "";
  }
}
