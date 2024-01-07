export default {
  mounted() {
    this.el.addEventListener("click", () => {
      const copyText = this.el.dataset.copy;
      navigator.clipboard
        .writeText(copyText)
        .then(() => {
          this.el.innerText = "Copied!";
        })
        .catch((err) => {
          this.el.innerText = "Error :(";
        });
      setTimeout(() => {
        this.el.innerText = "Copy";
      }, 2000);
    });
  },
};
