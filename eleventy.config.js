import { HtmlBasePlugin } from "@11ty/eleventy";
import { execFile } from "node:child_process";
import { stat } from "node:fs/promises";
import { promisify } from "node:util";

const PDF_TEMPLATE = "_includes/article.tex"; // pandoc's default LaTeX template (pandoc -D latex), to edit freely
const PDF_FILTER = "_includes/lettrine.lua"; // decorated initial on the first paragraph
const mtime = (file) => stat(file).then((s) => s.mtimeMs, () => 0); // 0 if the file does not exist

// Typesets one article as a PDF with pandoc and LaTeX, unless the PDF is already up to date.
async function buildPdf(markdown, pdf) {
  const sources = await Promise.all([markdown, PDF_TEMPLATE, PDF_FILTER].map(mtime));
  if ((await mtime(pdf)) > Math.max(...sources)) return;
  await promisify(execFile)("pandoc", [
    markdown,
    `--output=${pdf}`,
    `--template=${PDF_TEMPLATE}`,
    `--lua-filter=${PDF_FILTER}`,
    "--pdf-engine=xelatex",
    "--shift-heading-level-by=-1", // the title is the only level 1 heading, as on the web page
  ]);
  console.log(`[pdf] Writing ${pdf} from ${markdown}`);
}

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

  // Every article page links to a PDF of itself, written next to it (Foo.html, Foo.pdf).
  eleventyConfig.on("eleventy.after", async ({ results }) => {
    const articles = results.filter((r) => /^\.\/articles\/.*\.md$/.test(r.inputPath));
    try {
      await Promise.all(articles.map((r) => buildPdf(r.inputPath, r.outputPath.replace(/\.html$/, ".pdf"))));
    } catch (error) {
      // Without pandoc the site still builds on your own machine, only the PDF links are dead.
      if (error.code !== "ENOENT" || process.env.CI) throw error;
      console.warn("[pdf] pandoc is not installed: skipping the PDFs");
    }
  });

  // Sessions list articles by file name.
  eleventyConfig.addFilter("findArticle", (articles, name) => articles.find((a) => a.fileSlug === name));
}
