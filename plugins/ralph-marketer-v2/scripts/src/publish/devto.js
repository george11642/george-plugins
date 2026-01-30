/**
 * Dev.to Publisher
 * Posts to Dev.to API with canonical URL.
 */

/**
 * Publish a content payload to Dev.to.
 *
 * @param {import('./index.js').ContentPayload} content
 * @param {object} config - Full .ralph/config.json
 * @param {string} [canonicalUrl] - Canonical URL pointing to the primary published location
 * @returns {Promise<{success: boolean, url?: string, id?: string, error?: string}>}
 */
export async function publishToDevto(content, config, canonicalUrl) {
  const apiKey = process.env.DEVTO_API_KEY;

  if (!apiKey) {
    return { success: false, error: 'DEVTO_API_KEY not configured' };
  }

  try {
    const articleBody = {
      article: {
        title: content.title,
        body_markdown: content.content_markdown,
        published: true,
        tags: (content.tags || []).slice(0, 4), // Dev.to allows max 4 tags
        description: content.meta_description || content.excerpt || '',
      },
    };

    if (canonicalUrl) {
      articleBody.article.canonical_url = canonicalUrl;
    }

    if (content.featured_image_url) {
      articleBody.article.main_image = content.featured_image_url;
    }

    console.log(`[devto] Publishing: "${content.title}"...`);
    const res = await fetch('https://dev.to/api/articles', {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify(articleBody),
    });

    if (!res.ok) {
      const errText = await res.text();
      return { success: false, error: `Dev.to publish failed (${res.status}): ${errText}` };
    }

    const data = await res.json();
    const url = data?.url;
    const id = data?.id?.toString();

    console.log(`[devto] Published successfully: ${url}`);

    return { success: true, url: url || undefined, id: id || undefined };
  } catch (err) {
    return { success: false, error: `Dev.to publisher error: ${err.message}` };
  }
}
