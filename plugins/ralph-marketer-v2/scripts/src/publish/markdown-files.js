/**
 * Local Markdown Fallback Publisher
 * Writes content to local markdown files as a fallback publishing target.
 */

import { mkdir, writeFile } from 'fs/promises';
import { join, dirname } from 'path';

/**
 * Build YAML frontmatter string from an object of key/value pairs.
 * @param {Record<string, unknown>} fields
 * @returns {string}
 */
function buildFrontmatter(fields) {
  const lines = ['---'];
  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined || value === null) continue;
    if (Array.isArray(value)) {
      lines.push(`${key}:`);
      for (const item of value) {
        lines.push(`  - ${JSON.stringify(item)}`);
      }
    } else if (typeof value === 'string' && (value.includes(':') || value.includes('"') || value.includes('\n'))) {
      lines.push(`${key}: ${JSON.stringify(value)}`);
    } else {
      lines.push(`${key}: ${value}`);
    }
  }
  lines.push('---');
  return lines.join('\n');
}

/**
 * Publish a content payload by writing it as a local markdown file.
 *
 * @param {import('./index.js').ContentPayload} content
 * @param {object} config - Full .ralph/config.json
 * @returns {Promise<{success: boolean, path?: string, error?: string}>}
 */
export async function publishToMarkdown(content, config) {
  try {
    const publishDir = join(process.cwd(), 'content', 'published');
    const filePath = join(publishDir, `${content.slug}.md`);

    // Ensure directory exists
    await mkdir(publishDir, { recursive: true });

    const frontmatter = buildFrontmatter({
      title: content.title,
      date: new Date().toISOString(),
      tags: content.tags || [],
      category: content.category_slug || '',
      meta_description: content.meta_description || '',
      seo_title: content.seo_title || content.title,
      excerpt: content.excerpt || '',
      featured_image: content.featured_image_url || '',
      author: content.author_name || '',
    });

    const fileContent = `${frontmatter}\n\n${content.content_markdown}\n`;

    console.log(`[markdown-files] Writing to ${filePath}...`);
    await writeFile(filePath, fileContent, 'utf-8');

    const relativePath = `content/published/${content.slug}.md`;
    console.log(`[markdown-files] Published successfully: ${relativePath}`);

    return { success: true, path: relativePath };
  } catch (err) {
    return { success: false, error: `Markdown publisher error: ${err.message}` };
  }
}
