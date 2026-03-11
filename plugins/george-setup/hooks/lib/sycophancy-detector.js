#!/usr/bin/env node

// Utility: Detect sycophantic (rubber-stamp) reviews by comparing text similarity

const STOP_WORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'shall', 'can', 'this', 'that', 'these',
  'those', 'it', 'its', 'i', 'you', 'he', 'she', 'we', 'they', 'me',
  'him', 'her', 'us', 'them', 'my', 'your', 'his', 'our', 'their',
  'of', 'in', 'to', 'for', 'with', 'on', 'at', 'from', 'by', 'about',
  'as', 'into', 'through', 'during', 'before', 'after', 'above', 'below',
  'and', 'but', 'or', 'nor', 'not', 'so', 'yet', 'both', 'either',
  'neither', 'each', 'every', 'all', 'any', 'few', 'more', 'most',
  'other', 'some', 'such', 'no', 'only', 'own', 'same', 'than', 'too',
  'very', 'just', 'also', 'if', 'then', 'else', 'when', 'where', 'how',
  'what', 'which', 'who', 'whom', 'why', 'there', 'here', 'up', 'out',
  'down', 'off', 'over', 'under', 'again', 'further', 'once',
]);

/**
 * Tokenize text into a set of meaningful words.
 * Lowercases, strips punctuation, removes stop words and short tokens.
 */
function tokenize(text) {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length > 2 && !STOP_WORDS.has(w));
  return new Set(words);
}

/**
 * Compute Jaccard similarity between two sets.
 */
function jaccard(setA, setB) {
  if (setA.size === 0 && setB.size === 0) return 1;
  let intersection = 0;
  for (const item of setA) {
    if (setB.has(item)) intersection++;
  }
  const union = setA.size + setB.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/**
 * Detects sycophantic (rubber-stamp) reviews by comparing text similarity.
 * @param {string[]} reviews - Array of review text outputs from agents
 * @param {number} threshold - Jaccard similarity threshold (default 0.7)
 * @returns {{ isSycophantic: boolean, similarity: number, details: string }}
 */
function detectSycophancy(reviews, threshold = 0.7) {
  if (!reviews || reviews.length < 2) {
    return { isSycophantic: false, similarity: 0, details: 'Need at least 2 reviews to compare.' };
  }

  const tokenSets = reviews.map(r => tokenize(r));

  // Compute all pairwise Jaccard similarities
  let totalSim = 0;
  let pairCount = 0;
  const pairDetails = [];

  for (let i = 0; i < tokenSets.length; i++) {
    for (let j = i + 1; j < tokenSets.length; j++) {
      const sim = jaccard(tokenSets[i], tokenSets[j]);
      totalSim += sim;
      pairCount++;
      pairDetails.push(`Review ${i + 1} vs ${j + 1}: ${(sim * 100).toFixed(1)}%`);
    }
  }

  const avgSimilarity = pairCount > 0 ? totalSim / pairCount : 0;
  const isSycophantic = avgSimilarity > threshold;

  const details = [
    `Compared ${reviews.length} reviews (${pairCount} pairs).`,
    `Average Jaccard similarity: ${(avgSimilarity * 100).toFixed(1)}% (threshold: ${(threshold * 100).toFixed(0)}%).`,
    ...pairDetails,
    isSycophantic
      ? 'VERDICT: Reviews appear rubber-stamped.'
      : 'VERDICT: Reviews show sufficient diversity.',
  ].join(' ');

  return { isSycophantic, similarity: avgSimilarity, details };
}

module.exports = { detectSycophancy, tokenize, jaccard };
