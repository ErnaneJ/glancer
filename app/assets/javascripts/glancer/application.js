import { Turbo } from "@hotwired/turbo-rails"
import * as Stimulus from "@hotwired/stimulus"

window.Turbo = Turbo;

import ChatController from "./controllers/chat_controller";
import MessageController from "./controllers/message_controller";

document.addEventListener("DOMContentLoaded", async () => {
  const application = Stimulus.Application.start();

  console.log("Registrando ChatController");
  await application.register("chat", ChatController);

  console.log("Registrando MessageController");
  await application.register("message", MessageController);
});