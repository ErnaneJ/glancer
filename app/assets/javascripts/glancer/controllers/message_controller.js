import { Controller } from "@hotwired/stimulus"

// Fallback step labels (English). Overridden at runtime by server-rendered
// translations passed through the `data-message-step-labels-value` attribute.
const DEFAULT_STEP_LABELS = {
  enriching:          "Enriching question…",
  retrieving_context: "Retrieving context…",
  generating_code:    "Generating query…",
  validating:         "Validating query…",
  executing:          "Executing on database…",
  humanizing:         "Preparing response…",
};

export default class extends Controller {
  static targets = ["input", "form", "submitBtn", "cancelBtn", "charCount", "runBtn", "downloadBtn", "resultsContainer", "micBtn", "mentionChips", "editBtn", "processingLabel"]
  static values  = { startUrl: String, tables: Array, stepLabels: Object, pollUrl: String, isProcessing: Boolean }

  connect() {
    if (this.hasInputTarget) {
      this._setupMentionBackdrop();
      this.autoResize();
      this.updateCharCount();
      this.scrollToBottom();
      this.inputTarget.focus();
      this.inputTarget.addEventListener("blur", () => {
        setTimeout(() => this._closeMentionDropdown(), 120);
      });
    }

    // Processing-placeholder mode: poll the server until the job finishes.
    if (this.hasIsProcessingValue && this.isProcessingValue) {
      this._startPolling();
    }
  }

  disconnect() {
    this._stopPolling();
  }

  // ── Form submission ──────────────────────────────────────────────────────────

  handleKeydown(event) {
    if (event.key === "Escape") {
      const dropdown = document.getElementById("mention-dropdown");
      if (dropdown && !dropdown.classList.contains("hidden")) return;
      if (this._isSubmitting) { event.preventDefault(); this.cancelSubmit(); }
      return;
    }
    if (event.key === "Enter" && !event.shiftKey && !event.ctrlKey && !event.metaKey) {
      event.preventDefault();
      if (this._isSubmitting) return;
      this.formTarget.requestSubmit();
    }
  }

  cancelSubmit() {
    if (this._abortController) this._abortController.abort();
  }

  async submit(event) {
    event.preventDefault();

    const input = this.inputTarget;
    const content = input?.value?.trim();
    if (!content) return;

    // Temp chat mode: create chat via /start, redirect to new chat page.
    if (this.hasStartUrlValue) {
      await this._startNewSession(content);
      return;
    }

    document.getElementById("chat-empty-state")?.remove();
    this._showTempUserMessage(content);

    this.setSubmitting(true);
    const formData = new FormData(this.formTarget);
    input.value = "";
    this.autoResize();
    this.updateCharCount();
    this._updateMentionChips();
    this._updateMentionBackdrop();
    this._closeMentionDropdown();

    this.showThinking();
    this._abortController = new AbortController();

    try {
      // Server enqueues the job and returns a Turbo Stream immediately.
      // The stream inserts a processing placeholder; polling handles the rest.
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body:   formData,
        signal: this._abortController.signal,
        headers: {
          "Accept":       "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        },
      });

      if (response.ok) {
        const html = await response.text();
        this.removeThinking();
        Turbo.renderStreamMessage(html);
        await new Promise(r => requestAnimationFrame(r));
        this.scrollToBottom();
      }
    } catch (error) {
      this.removeThinking();
      document.getElementById("temp-user-message")?.remove();
      if (error.name !== "AbortError") this.toast("Failed to send message", "error");
    } finally {
      this.setSubmitting(false);
      this._abortController = null;
    }
  }

  // ── Background-job polling ───────────────────────────────────────────────────
  // Activated on processing-placeholder elements (data-message-is-processing-value).
  // Polls every 2 s; on completion the server returns a Turbo Stream that
  // replaces this element with the rendered final message.

  _startPolling() {
    const labels = this.hasStepLabelsValue
      ? Object.values(this.stepLabelsValue)
      : Object.values(DEFAULT_STEP_LABELS);
    let i = 0;
    this._labelTimer = setInterval(() => {
      if (!this.hasProcessingLabelTarget) return;
      this.processingLabelTarget.textContent = labels[i % labels.length];
      i++;
    }, 1500);

    this._pollTimer = setInterval(() => this._poll(), 2000);
  }

  _stopPolling() {
    clearInterval(this._labelTimer);
    clearInterval(this._pollTimer);
    this._labelTimer = null;
    this._pollTimer  = null;
  }

  async _poll() {
    if (!this.hasPollUrlValue) return;
    try {
      const response = await fetch(this.pollUrlValue, {
        headers: {
          "Accept":       "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        },
      });

      if (response.status === 204) return; // still processing

      if (response.ok) {
        this._stopPolling();
        const html = await response.text();
        Turbo.renderStreamMessage(html);
        // Give Turbo two frames to finish DOM updates, then animate the new element.
        await new Promise(r => requestAnimationFrame(r));
        await new Promise(r => requestAnimationFrame(r));
        this.scrollToBottom();
        await this.typewriterEffect();
        this.highlightCode();
        if (window.glancerUpgradeMentions) window.glancerUpgradeMentions();
      }
    } catch { /* network error — retry on next tick */ }
  }

  _showTempUserMessage(content) {
    const messagesEl = document.getElementById("messages-list") || document.getElementById("chat-messages");
    if (!messagesEl) return;

    const now     = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    const rendered = this._renderMarkdown(content);

    const el = document.createElement("div");
    el.id = "temp-user-message";
    el.className = "message user flex justify-end";
    el.innerHTML = `
      <div class="max-w-[78%] sm:max-w-[65%] min-w-0">
        <div class="user-message-prose bg-primary-600 dark:bg-primary-700 text-white rounded-2xl rounded-tr-sm px-4 py-3 text-sm leading-relaxed prose prose-sm max-w-none overflow-hidden break-words">${rendered}</div>
        <div class="flex items-center justify-end mt-1.5 px-1">
          <span class="text-[11px] text-gray-400 dark:text-gray-500">${now}</span>
        </div>
      </div>
    `;
    messagesEl.appendChild(el);
    this.scrollToBottom();
  }

  // Minimal safe markdown renderer for temp messages (no external deps)
  _renderMarkdown(text) {
    // 1. Extract fenced code blocks to protect them from further processing
    const blocks = [];
    text = text.replace(/```(\w*)\n?([\s\S]*?)```/g, (_, lang, code) => {
      const escaped = code.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
      blocks.push(`<pre class="user-message-prose"><code>${escaped}</code></pre>`);
      return `\x00BLOCK${blocks.length - 1}\x00`;
    });

    // 2. HTML-escape remaining text
    text = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

    // 3. Extract inline code
    const inlines = [];
    text = text.replace(/`([^`\n]+)`/g, (_, code) => {
      inlines.push(`<code>${code}</code>`);
      return `\x00INLINE${inlines.length - 1}\x00`;
    });

    // 4. Bold, italic, line breaks
    text = text
      .replace(/\*\*([^*\n]+)\*\*/g, "<strong>$1</strong>")
      .replace(/\*([^*\n]+)\*/g, "<em>$1</em>")
      .replace(/\n/g, "<br>");

    // 5. Restore inline codes and blocks
    text = text.replace(/\x00INLINE(\d+)\x00/g, (_, i) => inlines[+i]);
    text = text.replace(/\x00BLOCK(\d+)\x00/g,  (_, i) => blocks[+i]);

    return text;
  }

  // ── New session (temp chat) ──────────────────────────────────────────────
  // Uses a plain JSON POST (no SSE) — the server creates the chat and runs the
  // full workflow synchronously, then returns the new chat_id for redirect.
  // The thinking-indicator timer provides visual feedback during the wait.

  async _startNewSession(content) {
    document.getElementById("chat-empty-state")?.remove();
    this._showTempUserMessage(content);
    this.inputTarget.value = "";
    this.autoResize();
    this.setSubmitting(true);
    this.showThinking();

    try {
      const body = new FormData();
      body.append("content", content);

      const response = await fetch(this.startUrlValue, {
        method: "POST",
        body,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken,
        }
      });

      const data = await response.json();
      if (!response.ok || !data.chat_id) {
        throw new Error(data.error || "Failed to start chat");
      }

      this.removeThinking();
      Turbo.visit(`/glancer/chats/${data.chat_id}`);

    } catch (err) {
      this.removeThinking();
      document.getElementById("temp-user-message")?.remove();
      this.toast(err.message || "Failed to start chat", "error");
    } finally {
      this.setSubmitting(false);
    }
  }

  // ── SQL execution ─────────────────────────────────────────────────────────

  async runQuery(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const messageId = btn.dataset.messageId;

    // Close all other open result sections
    document.querySelectorAll("[data-results-open='true']").forEach(section => {
      if (section.id !== `results-section-${messageId}`) {
        this._collapseResults(section);
      }
    });

    // Show loading in current container
    const container = document.getElementById(`results-${messageId}`);
    if (container) {
      container.style.transition = "none";
      container.style.maxHeight = "none";
      container.style.overflow = "";
      container.innerHTML = `
        <div class="flex items-center gap-2 px-4 py-3 text-xs text-gray-400 border-t border-gray-200 dark:border-gray-700">
          <span class="inline-block w-3 h-3 rounded-full border-2 border-gray-300 border-t-primary-500 animate-spin"></span>
          Executing query…
        </div>
      `;
    }

    btn.disabled = true;

    const editorWrapper = document.getElementById(`sql-editor-wrapper-${messageId}`);
    const editorEl = document.getElementById(`sql-editor-${messageId}`);
    const isEditing = editorWrapper && !editorWrapper.classList.contains("hidden");
    const customCode = isEditing ? editorEl?.textContent?.trim() : null;

    try {
      const body = new FormData();
      if (customCode) body.append("custom_code", customCode);

      const response = await fetch(`/glancer/messages/${messageId}/run_code`, {
        method: "POST",
        body: customCode ? body : undefined,
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        }
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      // Update code display with the saved code
      if (isEditing && customCode) {
        const codeEl = document.getElementById(`sql-code-${messageId}`);
        if (codeEl) {
          codeEl.textContent = customCode;
          if (window.Prism) Prism.highlightElement(codeEl);
        }
        // Update the copy button's data-sql attribute
        const scope = btn.closest("[data-controller='message']");
        const copyBtn = scope?.querySelector("[data-action='click->message#copySql']");
        if (copyBtn) copyBtn.dataset.sql = customCode;
      }

      // Exit edit mode and reset button text
      if (isEditing) {
        this._exitEditMode(messageId);
        this._setRunBtnText(messageId, null); // null = use default from DOM
      }

    } catch (error) {
      if (container) {
        container.innerHTML = `<div class="px-4 py-3 text-xs text-red-500 border-t border-gray-200 dark:border-gray-700">Error: ${error.message}</div>`;
      }
    } finally {
      btn.disabled = false;
    }
  }

  exportToCSV(event) {
    event.preventDefault();

    const scope = event.currentTarget.closest("[data-controller='message']");
    const table = scope?.querySelector("table");

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

  // ── Results accordion ────────────────────────────────────────────────────

  toggleResults(event) {
    event.preventDefault();
    const messageId = event.currentTarget.dataset.messageId;
    const section   = document.getElementById(`results-section-${messageId}`);
    const container = document.getElementById(`results-${messageId}`);
    const arrow     = document.getElementById(`results-arrow-${messageId}`);
    if (!section || !container) return;

    const isOpen = section.dataset.resultsOpen === "true";

    if (isOpen) {
      this._collapseResults(section);
    } else {
      this._expandResults(section);
    }
  }

  _collapseResults(section) {
    const id        = section.id.replace("results-section-", "");
    const container = document.getElementById(`results-${id}`);
    const arrow     = document.getElementById(`results-arrow-${id}`);
    if (!container) return;

    // Animate from current height to 0
    const h = container.scrollHeight;
    container.style.transition = "none";
    container.style.maxHeight = h + "px";
    container.style.overflow = "hidden";
    container.offsetHeight; // force reflow
    container.style.transition = "max-height 0.3s ease";
    container.style.maxHeight = "0";
    section.dataset.resultsOpen = "false";
    if (arrow) arrow.style.transform = "rotate(-90deg)";
  }

  _expandResults(section) {
    const id        = section.id.replace("results-section-", "");
    const container = document.getElementById(`results-${id}`);
    const arrow     = document.getElementById(`results-arrow-${id}`);
    if (!container) return;

    container.style.transition = "max-height 0.3s ease";
    container.style.overflow = "hidden";
    container.style.maxHeight = container.scrollHeight + "px";
    section.dataset.resultsOpen = "true";
    if (arrow) arrow.style.transform = "rotate(0deg)";
    container.addEventListener("transitionend", () => {
      container.style.maxHeight = "none";
      container.style.overflow = "";
    }, { once: true });
  }

  // Opens a full-screen dialog with the result table for the given message.
  openFullscreenTable(event) {
    const messageId = event.currentTarget.dataset.messageId;
    const source    = document.getElementById(`results-${messageId}`);
    const tableEl   = source?.querySelector("table");
    if (!tableEl) return;

    const dialog = document.createElement("dialog");
    dialog.className = "glancer-fullscreen-dialog";
    dialog.innerHTML = `
      <div class="glancer-fullscreen-inner">
        <div class="glancer-fullscreen-toolbar">
          <span class="glancer-fullscreen-title">Results</span>
          <button class="glancer-fullscreen-close" aria-label="Close">
            <svg class="w-4 h-4" aria-hidden="true"><use href="#icon-x"/></svg>
          </button>
        </div>
        <div class="glancer-fullscreen-body">
          ${tableEl.outerHTML}
        </div>
      </div>
    `;
    document.body.appendChild(dialog);
    dialog.showModal();

    const close = () => { dialog.close(); dialog.remove(); };
    dialog.querySelector(".glancer-fullscreen-close").addEventListener("click", close);
    dialog.addEventListener("click", e => { if (e.target === dialog) close(); });
    dialog.addEventListener("close", () => dialog.remove());
  }

  // ── SQL editing ──────────────────────────────────────────────────────────

  toggleEditSql(event) {
    const messageId = event.currentTarget.dataset.messageId;
    this._toggleEditMode(messageId);
  }

  _toggleEditMode(messageId) {
    const codeWrapper  = document.getElementById(`sql-code-wrapper-${messageId}`);
    const editorWrapper = document.getElementById(`sql-editor-wrapper-${messageId}`);
    const editorEl     = document.getElementById(`sql-editor-${messageId}`);
    const codeEl       = document.getElementById(`sql-code-${messageId}`);
    if (!editorWrapper || !codeWrapper) return;

    const isEditing = !editorWrapper.classList.contains("hidden");
    if (isEditing) {
      this._exitEditMode(messageId);
      this._setRunBtnText(messageId, null);
    } else {
      const code = codeEl?.textContent?.trim() || "";
      editorEl.textContent = code;
      this._setupCodeEditor(editorEl, messageId);
      if (window.Prism) {
        const lang    = editorEl.classList.contains("language-ruby") ? "ruby" : "sql";
        const grammar = Prism.languages[lang];
        if (grammar) editorEl.innerHTML = Prism.highlight(code, grammar, lang);
      }
      editorWrapper.classList.remove("hidden");
      codeWrapper.classList.add("hidden");
      editorEl.focus();
      // Move cursor to end
      const range = document.createRange();
      range.selectNodeContents(editorEl);
      range.collapse(false);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
      this._setRunBtnText(messageId, "save_run");
      this._setEditBtnState(true);
    }
  }

  _exitEditMode(messageId) {
    document.getElementById(`sql-editor-wrapper-${messageId}`)?.classList.add("hidden");
    document.getElementById(`sql-code-wrapper-${messageId}`)?.classList.remove("hidden");
    this._setEditBtnState(false);
  }

  _setEditBtnState(editing) {
    if (!this.hasEditBtnTarget) return;
    const use = this.editBtnTarget.querySelector("use");
    if (use) use.setAttribute("href", editing ? "#icon-x" : "#icon-edit");
    this.editBtnTarget.setAttribute("aria-label", editing ? "Cancel edit" : "Edit code");
  }

  _setRunBtnText(messageId, key) {
    const btn = document.querySelector(`[data-message-id="${messageId}"][data-message-target="runBtn"] span`);
    if (!btn) return;
    if (key === "save_run") {
      btn.textContent = btn.closest("button")?.dataset?.saveRunLabel || "Save & Run";
    } else {
      btn.textContent = btn.closest("button")?.dataset?.runLabel || "Run";
    }
  }

  // ── Copy actions ─────────────────────────────────────────────────────────

  copySql(event) {
    const sql = event.currentTarget.dataset.sql;
    navigator.clipboard.writeText(sql)
      .then(() => this.toast("SQL copied", "success"))
      .catch(() => this.toast("Failed to copy", "error"));
  }

  copyText(event) {
    const msgEl = event.currentTarget.closest(".message.assistant");
    const text = msgEl?.querySelector(".message-content")?.innerText || "";
    navigator.clipboard.writeText(text)
      .then(() => this.toast("Text copied", "success"))
      .catch(() => this.toast("Failed to copy", "error"));
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

  // ── Audio recording (Web Speech API) ────────────────────────────────────

  toggleRecording() {
    if (this.recording) {
      this.recognition?.stop();
      return;
    }

    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) {
      this.toast("Speech recognition not supported in this browser", "error");
      return;
    }

    // Determine language: use setting from <html> data attr, fallback to browser lang
    const htmlEl = document.documentElement;
    const settingLang = htmlEl.dataset.speechLang;
    const lang = (settingLang && settingLang !== "auto") ? settingLang : (navigator.language || "en-US");

    this.recognition = new SR();
    this.recognition.lang = lang;
    this.recognition.continuous = false;
    this.recognition.interimResults = false;

    this.recognition.onstart = () => {
      this.recording = true;
      if (this.hasMicBtnTarget) {
        this.micBtnTarget.classList.add("text-red-500", "animate-pulse");
        this.micBtnTarget.querySelector("use")?.setAttribute("href", "#icon-mic-off");
        this.micBtnTarget.setAttribute("aria-label", "Stop recording");
      }
    };

    this.recognition.onresult = (e) => {
      const transcript = e.results[0][0].transcript;
      if (this.hasInputTarget) {
        this.inputTarget.value += (this.inputTarget.value ? " " : "") + transcript;
        this.autoResize();
        this.updateCharCount();
        this.inputTarget.focus();
      }
    };

    this.recognition.onerror = () => {
      this.toast("Speech recognition error", "error");
    };

    this.recognition.onend = () => {
      this.recording = false;
      if (this.hasMicBtnTarget) {
        this.micBtnTarget.classList.remove("text-red-500", "animate-pulse");
        this.micBtnTarget.querySelector("use")?.setAttribute("href", "#icon-mic");
        this.micBtnTarget.setAttribute("aria-label", "Record audio");
      }
    };

    this.recognition.start();
  }

  // ── @ mention autocomplete ───────────────────────────────────────────────

  handleMentionInput() {
    this._updateMentionDropdown();
    this._updateMentionChips();
    this._updateMentionBackdrop();
  }

  handleMentionKeydown(event) {
    const dropdown = document.getElementById("mention-dropdown");
    if (!dropdown || dropdown.classList.contains("hidden")) return;

    const items = [...dropdown.querySelectorAll("[data-mention-table]")];
    if (!items.length) return;

    const activeIdx = items.findIndex(el => el.classList.contains("bg-primary-50"));

    if (event.key === "ArrowDown") {
      event.preventDefault();
      const next = (activeIdx + 1) % items.length;
      items.forEach(el => el.classList.remove("bg-primary-50", "dark:bg-primary-950/40"));
      items[next].classList.add("bg-primary-50", "dark:bg-primary-950/40");
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      const prev = (activeIdx - 1 + items.length) % items.length;
      items.forEach(el => el.classList.remove("bg-primary-50", "dark:bg-primary-950/40"));
      items[prev].classList.add("bg-primary-50", "dark:bg-primary-950/40");
    } else if (event.key === "Enter" || event.key === "Tab") {
      const active = activeIdx >= 0 ? items[activeIdx] : items[0];
      if (active) {
        event.preventDefault();
        this._selectMention(active.dataset.mentionTable);
      }
    } else if (event.key === "Escape") {
      this._closeMentionDropdown();
    }
  }

  _getTables() {
    return this.hasTablesValue ? this.tablesValue : [];
  }

  _updateMentionDropdown() {
    if (!this.hasInputTarget) return;

    const input  = this.inputTarget;
    const pos    = input.selectionStart;
    const before = input.value.slice(0, pos);
    const match  = before.match(/@(\w*)$/);

    if (!match) { this._closeMentionDropdown(); return; }

    const query  = match[1].toLowerCase();
    const tables = this._getTables().filter(t => !query || t.toLowerCase().includes(query));

    if (!tables.length) { this._closeMentionDropdown(); return; }

    this._mentionStart = pos - match[0].length;

    let dropdown = document.getElementById("mention-dropdown");
    if (!dropdown) return;

    dropdown.innerHTML = tables.slice(0, 12).map((t, i) => {
      const highlighted = t.replace(
        new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "gi"),
        '<mark class="bg-primary-100 dark:bg-primary-900/60 text-primary-700 dark:text-primary-300 not-italic rounded">$1</mark>'
      );
      return `<button type="button"
        class="w-full text-left px-4 py-2 flex items-center gap-2 text-gray-700 dark:text-gray-300 hover:bg-primary-50 dark:hover:bg-primary-950/40 transition-colors ${i === 0 ? "bg-primary-50 dark:bg-primary-950/40" : ""}"
        data-mention-table="${t}"
        role="option">
        <svg class="w-3.5 h-3.5 text-primary-400 flex-shrink-0" aria-hidden="true"><use href="#icon-table"/></svg>
        <span>${highlighted}</span>
      </button>`;
    }).join("");

    dropdown.classList.remove("hidden");

    dropdown.querySelectorAll("[data-mention-table]").forEach(btn => {
      btn.addEventListener("mousedown", (e) => {
        e.preventDefault();
        this._selectMention(btn.dataset.mentionTable);
      });
    });
  }

  _closeMentionDropdown() {
    const dropdown = document.getElementById("mention-dropdown");
    if (dropdown) dropdown.classList.add("hidden");
    this._mentionStart = null;
  }

  _selectMention(tableName) {
    if (!this.hasInputTarget || this._mentionStart == null) return;

    const input = this.inputTarget;
    const pos   = input.selectionStart;
    const val   = input.value;

    input.value = val.slice(0, this._mentionStart) + "@" + tableName + " " + val.slice(pos);

    const newPos = this._mentionStart + tableName.length + 2;
    input.setSelectionRange(newPos, newPos);

    this._closeMentionDropdown();
    this._updateMentionChips();
    this._updateMentionBackdrop();
    this.autoResize();
    this.updateCharCount();
    input.focus();
  }

  _updateMentionChips() {
    if (!this.hasMentionChipsTarget || !this.hasInputTarget) return;

    const tables    = new Set(this._getTables());
    const matches   = [...this.inputTarget.value.matchAll(/@(\w+)/g)]
                        .map(m => m[1])
                        .filter(n => tables.has(n));
    const unique    = [...new Set(matches)];
    const chipsEl   = this.mentionChipsTarget;

    if (!unique.length) {
      chipsEl.classList.add("hidden");
      chipsEl.innerHTML = "";
      return;
    }

    const schemaBase = document.querySelector("meta[name='glancer-schema-path']")?.content || "/glancer/db-schema";
    chipsEl.classList.remove("hidden");
    chipsEl.innerHTML = unique.map(t =>
      `<a href="${schemaBase}?table=${encodeURIComponent(t)}" target="_blank" rel="noopener" class="mention-chip">
        <svg class="w-3 h-3 opacity-60" aria-hidden="true"><use href="#icon-table"/></svg>
        ${t}
      </a>`
    ).join("");
  }

  // ── @ mention backdrop (highlights @table in the textarea) ───────────────

  _setupMentionBackdrop() {
    if (!this.hasInputTarget) return;
    const ta = this.inputTarget;
    const container = ta.parentElement;
    if (!container || container.querySelector(".mention-backdrop")) return;

    container.style.position = "relative";

    const bd = document.createElement("div");
    bd.className = "mention-backdrop";
    bd.setAttribute("aria-hidden", "true");
    container.insertBefore(bd, ta);

    // Copy computed layout styles so backdrop aligns pixel-perfectly with the textarea
    requestAnimationFrame(() => {
      const cs = window.getComputedStyle(ta);
      bd.style.padding       = cs.padding;
      bd.style.fontFamily    = cs.fontFamily;
      bd.style.fontSize      = cs.fontSize;
      bd.style.fontWeight    = cs.fontWeight;
      bd.style.lineHeight    = cs.lineHeight;
      bd.style.letterSpacing = cs.letterSpacing;
      bd.style.wordBreak     = "break-word";
    });

    ta.addEventListener("scroll", () => { bd.scrollTop = ta.scrollTop; });
  }

  _updateMentionBackdrop() {
    if (!this.hasInputTarget) return;
    const bd = this.inputTarget.parentElement?.querySelector(".mention-backdrop");
    if (!bd) return;

    const tables  = new Set(this._getTables());
    const escaped = (this.inputTarget.value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

    bd.innerHTML = escaped.replace(/@(\w+)/g, (match, name) =>
      tables.has(name) ? `<mark class="mention-hl">${match}</mark>` : match
    );
    bd.scrollTop = this.inputTarget.scrollTop;
  }

  // ── Code editor (contenteditable + Prism live highlighting) ──────────────

  _getCaretOffset(el) {
    const sel = window.getSelection();
    if (!sel || !sel.rangeCount) return 0;
    const range = sel.getRangeAt(0).cloneRange();
    range.selectNodeContents(el);
    range.setEnd(sel.getRangeAt(0).endContainer, sel.getRangeAt(0).endOffset);
    return range.toString().length;
  }

  _setCaretOffset(el, offset) {
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    let node;
    let rem = offset;
    while ((node = walker.nextNode())) {
      if (rem <= node.length) {
        const range = document.createRange();
        range.setStart(node, rem);
        range.collapse(true);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        return;
      }
      rem -= node.length;
    }
  }

  _rehighlightEditor(el) {
    if (!window.Prism) return;
    const lang    = el.classList.contains("language-ruby") ? "ruby" : "sql";
    const grammar = Prism.languages[lang];
    if (!grammar) return;

    const offset = this._getCaretOffset(el);
    el.innerHTML = Prism.highlight(el.textContent, grammar, lang);
    this._setCaretOffset(el, offset);
  }

  _setupCodeEditor(editorEl, messageId) {
    if (editorEl._glancerSetup) return;
    editorEl._glancerSetup = true;

    editorEl.addEventListener("input", () => this._rehighlightEditor(editorEl));

    // Plain-text paste only
    editorEl.addEventListener("paste", (e) => {
      e.preventDefault();
      const text = e.clipboardData.getData("text/plain");
      document.execCommand("insertText", false, text);
    });

    editorEl.addEventListener("keydown", (e) => {
      if (e.key === "Tab") {
        e.preventDefault();
        document.execCommand("insertText", false, "  ");
      } else if (e.key === "Escape") {
        e.preventDefault();
        const mid = messageId || editorEl.id.replace("sql-editor-", "");
        this._exitEditMode(mid);
        this._setRunBtnText(mid, null);
      }
    });
  }

  // ── UX helpers ──────────────────────────────────────────────────────────

  autoResize() {
    if (!this.hasInputTarget) return;
    const el = this.inputTarget;
    el.style.height = "auto";
    el.style.height = `${Math.min(Math.max(el.scrollHeight, 42), 200)}px`;
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
    this._isSubmitting = loading;
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = loading;
    if (this.hasCancelBtnTarget) this.cancelBtnTarget.classList.toggle("hidden", !loading);
  }

  // ── Thinking indicator ────────────────────────────────────────────────────
  // Label updates are driven by real SSE status events from the server.
  // A local timer also cycles labels so users always see progress even when
  // the server buffers all SSE events and delivers them in one batch.

  showThinking() {
    this.removeThinking();

    const el = document.createElement("div");
    el.id = "thinking-indicator";
    el.className = "flex items-start gap-3";
    el.innerHTML = `
      <div class="flex-shrink-0 w-7 h-7 rounded-lg bg-primary-100 dark:bg-primary-950 flex items-center justify-center" aria-hidden="true">
        <svg class="w-3.5 h-3.5 text-primary-600 dark:text-primary-400"><use href="#icon-database"/></svg>
      </div>
      <div class="flex items-center gap-2 mt-2 text-xs text-gray-400 dark:text-gray-500" role="status" aria-live="polite">
        <span id="thinking-label">Processing…</span>
        <span class="flex gap-0.5" aria-hidden="true">
          <span class="w-1.5 h-1.5 rounded-full bg-primary-400 dark:bg-primary-500 animate-bounce" style="animation-delay:0ms"></span>
          <span class="w-1.5 h-1.5 rounded-full bg-primary-400 dark:bg-primary-500 animate-bounce" style="animation-delay:150ms"></span>
          <span class="w-1.5 h-1.5 rounded-full bg-primary-400 dark:bg-primary-500 animate-bounce" style="animation-delay:300ms"></span>
        </span>
      </div>
    `;

    (document.getElementById("messages-list") || document.getElementById("chat-messages"))?.appendChild(el);
    this.scrollToBottom();

    // Cycle step labels on a timer so the UI always shows progress,
    // even when SSE events arrive buffered in a single chunk at the end.
    const labels = this.hasStepLabelsValue
      ? Object.values(this.stepLabelsValue)
      : Object.values(DEFAULT_STEP_LABELS);
    let i = 0;
    this._thinkingTimer = setInterval(() => {
      const labelEl = document.getElementById("thinking-label");
      if (!labelEl) { clearInterval(this._thinkingTimer); return; }
      labelEl.textContent = labels[i % labels.length];
      i++;
    }, 1500);
  }

  removeThinking() {
    if (this._thinkingTimer) {
      clearInterval(this._thinkingTimer);
      this._thinkingTimer = null;
    }
    document.getElementById("thinking-indicator")?.remove();
  }

  // ── Typewriter effect ─────────────────────────────────────────────────────

  async typewriterEffect() {
    const msgEl = document.querySelector(".message.assistant:last-of-type");
    const el    = msgEl?.querySelector(".message-content");
    if (!el) return;

    // Hide SQL block — will slide in after text animation completes
    const sqlBlock = msgEl.querySelector("[data-sql-block]");
    if (sqlBlock) {
      sqlBlock.style.overflow   = "hidden";
      sqlBlock.style.maxHeight  = "0";
      sqlBlock.style.opacity    = "0";
      sqlBlock.style.transition = "";
    }

    const html = el.innerHTML;
    el.innerHTML = '<span class="cursor-blink" aria-hidden="true">|</span>';

    const append = async (node, target) => {
      if (node.nodeType === Node.TEXT_NODE) {
        for (const ch of node.textContent) {
          target.append(ch);
          await new Promise(r => setTimeout(r, 8));
        }
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        const clone = node.cloneNode(false);
        target.appendChild(clone);
        for (const child of node.childNodes) await append(child, clone);
      }
    };

    const tmp = document.createElement("div");
    tmp.innerHTML = html;
    const cursor = Object.assign(document.createElement("span"), {
      className: "cursor-blink",
      textContent: "|",
      ariaHidden: "true"
    });

    for (const node of tmp.childNodes) {
      if (el.lastChild?.classList?.contains("cursor-blink")) el.removeChild(el.lastChild);
      await append(node, el);
      el.appendChild(cursor);
    }

    el.innerHTML = html;
    this.highlightCode();

    // Slide in the SQL block now that text is fully rendered
    if (sqlBlock) {
      requestAnimationFrame(() => {
        sqlBlock.style.transition = "max-height 0.6s ease, opacity 0.45s ease 0.1s";
        sqlBlock.style.maxHeight  = `${sqlBlock.scrollHeight + 400}px`;
        sqlBlock.style.opacity    = "1";
        sqlBlock.addEventListener("transitionend", () => {
          sqlBlock.style.maxHeight  = "none";
          sqlBlock.style.overflow   = "";
        }, { once: true });
      });
    }
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
