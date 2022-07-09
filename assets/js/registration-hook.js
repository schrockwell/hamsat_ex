export default {
  mounted() {
    this.handleEvent("sumbit-registration-form", () => {
      this.el.submit();
    });
  },
};
