import { HtmlBasePlugin } from "@11ty/eleventy";

// Front matter dates are written freely ("18.11.2026", "February 8, 1996", 1907).
// Parse what we can (used for sorting only); pages display the date as written.
function parseDate(value) {
  if (value instanceof Date) return value;
  const s = String(value ?? "").trim();
  let m;
  if ((m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/))) return new Date(Date.UTC(+m[3], m[2] - 1, +m[1]));
  if ((m = s.match(/^\d{4}$/))) return new Date(Date.UTC(+s, 0, 1));
  const t = Date.parse(s);
  if (!isNaN(t)) return new Date(t);
}

export const config = { markdownTemplateEngine: false }; // articles are plain markdown

export default function (eleventyConfig) {
  eleventyConfig.ignores.add("**/_*.md"); // files starting with "_" are not published
  eleventyConfig.addPlugin(HtmlBasePlugin); // makes links work under a --pathprefix
  eleventyConfig.addPassthroughCopy("style.css");
  eleventyConfig.addPassthroughCopy("fonts");
  eleventyConfig.addDateParsing(parseDate);

  // Flat output: Foo.md becomes Foo.html; README.md is the home page.
  eleventyConfig.addGlobalData("eleventyComputed", {
    permalink: (data) => (data.page.filePathStem === "/README" ? "/index.html" : `${data.page.filePathStem}.html`),
  });

  eleventyConfig.addCollection("sessions", (api) => api.getFilteredByGlob("sessions/*.md").reverse());
  eleventyConfig.addCollection("articles", (api) =>
    api.getFilteredByGlob("articles/*.md").sort((a, b) => a.data.title.localeCompare(b.data.title)),
  );

  // Sessions list articles by file name.
  eleventyConfig.addFilter("findArticle", (articles, name) => articles.find((a) => a.fileSlug === name));
}
