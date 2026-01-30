/**
 * Supabase Publisher
 * Publishes content to the blog_posts table via @supabase/supabase-js with service role key.
 */

import { createClient } from '@supabase/supabase-js';

/**
 * Publish a content payload to Supabase blog_posts table.
 *
 * @param {import('./index.js').ContentPayload} content
 * @param {object} config - Full .ralph/config.json
 * @returns {Promise<{success: boolean, url?: string, id?: string, error?: string}>}
 */
export async function publishToSupabase(content, config) {
  const supabaseUrlEnv = config?.stack?.supabase_url_env || 'SUPABASE_URL';
  const supabaseKeyEnv = config?.stack?.supabase_key_env || 'SUPABASE_SERVICE_ROLE_KEY';

  const supabaseUrl = process.env[supabaseUrlEnv];
  const supabaseKey = process.env[supabaseKeyEnv];

  if (!supabaseUrl) {
    return { success: false, error: `${supabaseUrlEnv} not configured in environment` };
  }
  if (!supabaseKey) {
    return { success: false, error: `${supabaseKeyEnv} not configured in environment` };
  }

  try {
    console.log(`[supabase] Connecting to ${supabaseUrl}...`);
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Look up category_id from category_slug if provided
    let categoryId = null;
    if (content.category_slug) {
      console.log(`[supabase] Looking up category: ${content.category_slug}`);
      const { data: category, error: catError } = await supabase
        .from('blog_categories')
        .select('id')
        .eq('slug', content.category_slug)
        .single();

      if (catError) {
        console.log(`[supabase] Category lookup warning: ${catError.message} (proceeding without category)`);
      } else if (category) {
        categoryId = category.id;
      }
    }

    // Build the row to upsert
    const row = {
      title: content.title,
      slug: content.slug,
      content_markdown: content.content_markdown,
      content_html: content.content_html,
      excerpt: content.excerpt,
      meta_description: content.meta_description,
      seo_title: content.seo_title || content.title,
      tags: content.tags || [],
      featured_image_url: content.featured_image_url || null,
      status: 'published',
      published_at: new Date().toISOString(),
    };

    if (categoryId) {
      row.category_id = categoryId;
    }

    console.log(`[supabase] Upserting post: "${content.title}" (slug: ${content.slug})`);
    const { data: post, error: upsertError } = await supabase
      .from('blog_posts')
      .upsert(row, { onConflict: 'slug' })
      .select('id, slug')
      .single();

    if (upsertError) {
      return { success: false, error: `Supabase upsert failed: ${upsertError.message}` };
    }

    const url = `/blog/${post.slug}`;
    console.log(`[supabase] Published successfully: ${url} (id: ${post.id})`);

    return { success: true, url, id: post.id };
  } catch (err) {
    return { success: false, error: `Supabase publisher error: ${err.message}` };
  }
}
