import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("[ChatController] Connected!")
    this.setupEventListeners();
  }
  
  disconnect() {
    this.removeEventListeners();
  }
  
  setupEventListeners() {
    document.addEventListener("new-chat", this.handleNewChat.bind(this))
    document.addEventListener("chat-selected", this.handleChatSelected.bind(this))
  }
  
  removeEventListeners() {
    document.removeEventListener("new-chat", this.handleNewChat.bind(this))
    document.removeEventListener("chat-selected", this.handleChatSelected.bind(this))
  }
  
  create(event) {
    event.preventDefault();

    fetch(event.target.href, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      }
    })
    .then(response => response.text())
    .then(html => Turbo.renderStreamMessage(html))
    .catch(error => console.error("Error creating chat:", error))
  }

  copy(event) {
    const button = event.currentTarget;
    const content = button.dataset.message;

    navigator.clipboard.writeText(content).then(() => {
      button.classList.add('text-green-500');
      setTimeout(() => button.classList.remove('text-green-500'), 1000);
    });
  }
    
  select(event) {
    event.preventDefault()
    const chatId = event.currentTarget.dataset.chatId
    Turbo.visit(`/glancer/chats/${chatId}`)
  }
  
  handleNewChat(event) {
    console.log("New chat event received", event.detail)
  }
  
  handleChatSelected(event) {
    console.log("Chat selected", event.detail.chatId)
  }
}