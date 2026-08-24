// Hooks for the activation chat window.

// Keeps the message list pinned to the newest message, unless the user has
// scrolled up to read history.
export const ChatMessages = {
  mounted() {
    this.scrollToBottom();
  },

  updated() {
    if (this.nearBottom) {
      this.scrollToBottom();
    }
  },

  beforeUpdate() {
    const distance =
      this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight;
    this.nearBottom = distance < 60;
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },
};

// LiveView won't patch a focused input, so clear the message box ourselves
// after the submit event is pushed.
export const ChatForm = {
  mounted() {
    this.el.addEventListener("submit", () => {
      window.setTimeout(() => {
        const input = this.el.querySelector("input[type='text']");
        if (input) {
          input.value = "";
          input.focus();
        }
      }, 0);
    });
  },
};
