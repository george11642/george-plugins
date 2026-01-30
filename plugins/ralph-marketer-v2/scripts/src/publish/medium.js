/**
 * Medium Publisher
 * Posts to Medium API with canonical URL pointing back to primary.
 */

/**
 * Publish a content payload to Medium.
 *
 * @param {import('./index.js').ContentPayload} content
 * @param {object} config - Full .ralph/config.json
 * @param {string} [canonicalUrl] - Canonical URL pointing to the primary published location
 * @returns {Promise<{success: boolean, url?: string, id?: string, error?: string}>}
 */
export async function publishToMedium(content, config, canonicalUrl) {
  const token = process.env.MEDIUM_TOKEN;

  if (!token) {
    return { success: false, error: 'MEDIUM_TOKEN not configured' };
  }

  try {
    // Step 1: Get the authenticated user ID
    console.log('[medium] Fetching authenticated user...');
    const userRes = await fetch('https://api.medium.com/v1/me', {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    });

    if (!userRes.ok) {
      const errText = await userRes.text();
      return { success: false, error: `Medium auth failed (${userRes.status}): ${errText}` };
    }

    const userData = await userRes.json();
    const userId = userData?.data?.id;

    if (!userId) {
      return { success: false, error: 'Medium: could not resolve user ID from /v1/me' };
    }

    console.log(`[medium] Authenticated as user: ${userId}`);

    // Step 2: Create the post
    const postBody = {
      title: content.title,
      contentFormat: 'markdown',
      content: content.content_markdown,
      tags: (content.tags || []).slice(0, 5), // Medium allows max 5 tags
      publishStatus: 'public',
    };

    if (canonicalUrl) {
      postBody.canonicalUrl = canonicalUrl;
    }

    console.log(`[medium] Publishing: "${content.title}"...`);
    const postRes = await fetch(`https://api.medium.com/v1/users/${userId}/posts`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify(postBody),
    });

    if (!postRes.ok) {
      const errText = await postRes.text();
      return { success: false, error: `Medium publish failed (${postRes.status}): ${errText}` };
    }

    const postData = await postRes.json();
    const url = postData?.data?.url;
    const id = postData?.data?.id;

    console.log(`[medium] Published successfully: ${url}`);

    return { success: true, url: url || undefined, id: id || undefined };
  } catch (err) {
    return { success: false, error: `Medium publisher error: ${err.message}` };
  }
}
