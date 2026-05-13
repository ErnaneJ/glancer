import { Turbo } from "@hotwired/turbo-rails"
import * as Stimulus from "@hotwired/stimulus"

window.Turbo = Turbo;

import ChatController    from "./controllers/chat_controller";
import MessageController from "./controllers/message_controller";
import ToastController   from "./controllers/toast_controller";

document.addEventListener("DOMContentLoaded", () => {
  const application = Stimulus.Application.start();
  application.register("chat",    ChatController);
  application.register("message", MessageController);
  application.register("toast",   ToastController);
});
