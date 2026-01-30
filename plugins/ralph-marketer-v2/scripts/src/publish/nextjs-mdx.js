/**
 * Next.js MDX Publisher
 * For projects using MDX-based blogs. Writes content as .mdx files
 * to the blog location specified in config.
 */

import { mkdir, writeFile } from 'fs/promises';
import { join } from 'path';

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
 * Publish a content payload as an MDX file for Next.js blogs.
 *
 * @param {import('./index.js').ContentPayload} content
 * @param {object} config - Full .ralph/config.json
 * @returns {Promise<{success: boolean, path?: string, error?: string}>}
 */
export async function publishToMdx(content, config) {
  try {
    // Determine the blog directory from config or use a sensible default
    const blogDir = config?.stack?.blog_location
      || config?.publishing?.mdx_path
      || 'web/app/blog/posts';

    const outputDir = join(process.cwd(), blogDir);
    const filePath = join(outputDir, `${content.slug}.mdx`);

    // Ensure directory exists
    await mkdir(outputDir, { recursive: true });

    const frontmatter = buildFrontmatter({
      title: content.title,
      date: new Date().toISOString(),
      description: content.meta_description || content.excerpt || '',
      tags: content.tags || [],
      category: content.category_slug || '',
      image: content.featured_image_url || '',
      author: content.author_name || '',
    });

    const fileContent = `${frontmatter}\n\n${content.content_markdown}\n`;

    console.log(`[nextjs-mdx] Writing to ${filePath}...`);
    await writeFile(filePath, fileContent, 'utf-8');

    const relativePath = `${blogDir}/${content.slug}.mdx`;
    console.log(`[nextjs-mdx] Published successfully: ${relativePath}`);

    return { success: true, path: relativePath };
  } catch (err) {
    return { success: false, error: `MDX publisher error: ${err.message}` };
  }
}
