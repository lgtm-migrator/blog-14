'use strict';

import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkFrontmatter from 'remark-frontmatter';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import remarkGraphviz from 'remark-graphviz';
import remarkMermaid from 'remark-mermaid';
import remark2rehype from 'remark-rehype';
import rehypeHighlight from 'rehype-highlight';
import rehypeMath from 'rehype-katex';
import rehypeFormat from 'rehype-format';
import rehypeStringify from 'rehype-stringify';

function remark2rehypeHexoMoreHandler(h, node) {
  const newNode = h(node);
  newNode.type = 'comment';
  newNode.value = 'more';

  delete newNode.tagName;

  return newNode;
}

const engine = unified()
  .use(remarkParse)
  .use(remarkFrontmatter)
  .use(remarkGfm)
  .use(remarkMath)
  .use(remarkGraphviz)
  .use(remarkMermaid, { simple: true })
  .use(remark2rehype, {
    allowDangerousHTML: true,
    handlers: { excerptDelimitor: remark2rehypeHexoMoreHandler },
  })
  .use(rehypeMath)
  .use(rehypeHighlight, { ignoreMissing: true })
  .use(rehypeFormat)
  .use(rehypeStringify);

function renderer(data) {
  return String(engine.processSync(data.text));
}

module.exports = renderer;
