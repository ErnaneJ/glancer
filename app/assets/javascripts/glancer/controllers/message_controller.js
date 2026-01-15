import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("[MessageController] Connected!");
    this.inputTarget = document.querySelector('textarea[data-message-target="input"]');
    this.formTarget = document.querySelector('form[data-message-target="form"]');

    this.inputTarget?.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && !event.shiftKey && !event.ctrlKey && !event.metaKey) {
        this.submit(event);
      }
    });

    document.getElementById('chat-messages')?.scrollTo({
      top: document.getElementById('chat-messages').scrollHeight,
      behavior: 'smooth'
    });
  }

  async closeMessageInfo() {
    const messageInfoArea = document.getElementById('message-info--content');
    if (messageInfoArea) {
      messageInfoArea.style.transform = 'translateX(100%)';
      setTimeout(() => {
        document.getElementById('message-info--area').remove();
      }, 300);
    }
  }

  async openMessageInfo(event) {
    const messageId = event.currentTarget.dataset.messageId;

    try {
      const response = await fetch(`/glancer/messages/${messageId}/info`, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);

      setTimeout(() => {
        document.getElementById('message-info--content').style.transform = 'translateX(0)';
      }, 100);
    } catch (error) {
      console.error("[MessageController] Error:", error);
    }
  }
  
  async submit(event) {
    event.preventDefault();

    if (!this.inputTarget || !this.formTarget) {
      return;
    }

    if( this.inputTarget.value.trim() === '') {
      return;
    }
    
    this.formTarget.querySelector('button[type="submit"]').disabled = true;

    const formData = new FormData(this.formTarget);
    this.inputTarget.value = '';
    
    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: formData,
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      });
      
      const html = await response.text();
      Turbo.renderStreamMessage(html);
      
      setTimeout(async () => {
        document.getElementById('chat-messages').scrollTo({
          top: document.getElementById('chat-messages').scrollHeight,
          behavior: 'smooth'
        });
        await this.typewriterEffect();
      }, 100);
      
    } catch (error) {
      console.error("[MessageController] Error:", error);
    } finally {
      this.inputTarget.value = '';
      this.formTarget.querySelector('button[type="submit"]').disabled = false;
    }
  }
  
  async typewriterEffect() {
    const contentElement = document.querySelector('.message.assistant:last-of-type .message-content');
    if (!contentElement) return;

    const originalHTML = contentElement.innerHTML;

    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = originalHTML;

    contentElement.innerHTML = '<span class="cursor-blink">|</span>';

    const appendChar = async (el, container) => {
      if (el.nodeType === Node.TEXT_NODE) {
        const text = el.textContent;
        for (let i = 0; i < text.length; i++) {
          container.append(text[i]);
          await new Promise(res => setTimeout(res, 12)); // velocidade por caractere
        }
      } else if (el.nodeType === Node.ELEMENT_NODE) {
        const clone = el.cloneNode(false);
        container.appendChild(clone);
        for (let child of el.childNodes) {
          await appendChar(child, clone);
        }
      }
    };

    const cursor = document.createElement('span');
    cursor.className = 'cursor-blink';
    cursor.textContent = '|';

    for (const node of tempDiv.childNodes) {
      const lastChild = contentElement.lastChild;
      if (lastChild && lastChild.classList?.contains('cursor-blink')) {
        contentElement.removeChild(lastChild);
      }

      await appendChar(node, contentElement);
      contentElement.appendChild(cursor);
    }

    contentElement.innerHTML = originalHTML;
  }

  async runQuery(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const messageId = btn.dataset.messageId;
    const container = document.getElementById(`results-${messageId}`);

    btn.disabled = true;
    btn.classList.add('opacity-50');
    container.innerHTML = '<div class="text-xs text-gray-500 animate-pulse">Executing query...</div>';
    btn.querySelector('span').innerText = 'Running...';

    try {
      const response = await fetch(`/glancer/messages/${messageId}/run_sql`, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      });

      const html = await response.text();
      Turbo.renderStreamMessage(html);
      
      btn.querySelector('span').innerText = 'Re-executar Consulta';
    } catch (error) {
      container.innerHTML = `<div class="text-xs text-red-500">Error: ${error.message}</div>`;
    } finally {
      btn.disabled = false;
      btn.classList.remove('opacity-50');
    }
  }

  exportToCSV(event) {
    event.preventDefault();
    
    const resultsContainer = this.element.querySelector('[data-message-target="resultsContainer"]');
    const table = resultsContainer.querySelector('table');

    if (!table) {
      alert('No data available to export.');
      return;
    }

    let csvContent = '';
    const rows = table.querySelectorAll('tr');

    rows.forEach((row) => {
      const cols = row.querySelectorAll('th, td');
      const rowData = Array.from(cols).map(col => {
        const content = col.innerText.trim().replace(/"/g, '""');
        return `"${content}"`;
      }).join(',');
      csvContent += rowData + '\r\n';
    });

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    
    link.setAttribute('href', url);
    link.setAttribute('download', `glancer_results_${timestamp}.csv`);
    link.click();
    URL.revokeObjectURL(url);
  }

  stopPropagation(event) {
    event.stopPropagation();
  }
}