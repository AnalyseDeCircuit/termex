import { marked } from "marked";
import DOMPurify from "dompurify";

marked.setOptions({
  breaks: true,
  gfm: true,
});

/** Renders markdown to sanitized HTML. */
export function renderMarkdown(markdown: string): string {
  const raw = marked.parse(markdown, { async: false }) as string;
  return DOMPurify.sanitize(raw, {
    ALLOWED_TAGS: [
      "p", "br", "strong", "em", "code", "pre", "ul", "ol", "li",
      "h1", "h2", "h3", "blockquote", "a", "span",
    ],
    ALLOWED_ATTR: ["class", "href", "target"],
  });
}
