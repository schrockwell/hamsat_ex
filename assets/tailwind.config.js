// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex",
    "../lib/hamsat/modulation.ex",
  ],
  theme: {
    extend: {
      fontSize: {
        h1: "1.5rem",
        h2: "1.25rem",
      },
    },
  },
  plugins: [require("@tailwindcss/forms")],
};
