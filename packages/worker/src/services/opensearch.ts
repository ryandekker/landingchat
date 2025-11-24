/**
 * OpenSearch service for searching the apps catalog
 */

import type {
  UserProfile,
  SearchResultSummary,
  WorkerEnv,
  AppCatalogDocument
} from '@landingchat/shared';

/**
 * Simple OpenSearch client interface for Cloudflare Workers
 * Uses fetch directly for better compatibility
 */
export interface OpenSearchClient {
  url: string;
  username?: string;
  password?: string;
}

/**
 * Create OpenSearch client from environment
 */
export function createOpenSearchClient(env: WorkerEnv): OpenSearchClient {
  return {
    url: env.OPENSEARCH_URL,
    username: env.OPENSEARCH_USERNAME || undefined,
    password: env.OPENSEARCH_PASSWORD || undefined
  };
}

/**
 * Search apps catalog based on queries and user profile
 */
export async function searchApps(
  client: OpenSearchClient,
  env: WorkerEnv,
  profile: UserProfile,
  queries: string[]
): Promise<SearchResultSummary[]> {
  if (queries.length === 0) {
    return [];
  }

  // Build the search query
  const searchBody = {
    size: 5,
    query: {
      bool: {
        must: [
          {
            multi_match: {
              query: queries.join(' '),
              fields: ['title^2', 'description'],
              type: 'best_fields',
              operator: 'or'
            }
          }
        ],
        should: [
          // Boost by matching tags
          ...(profile.inferred_intent_tags.length > 0
            ? [
                {
                  terms: {
                    use_case_tags: profile.inferred_intent_tags,
                    boost: 2.0
                  }
                }
              ]
            : []),
          // Boost by industry
          ...(profile.attributes.industry
            ? [
                {
                  term: {
                    industry_tags: {
                      value: profile.attributes.industry.toLowerCase(),
                      boost: 1.5
                    }
                  }
                }
              ]
            : []),
          // Boost by complexity matching technical sophistication
          ...(profile.attributes.technical_sophistication
            ? [
                {
                  term: {
                    complexity: {
                      value: profile.attributes.technical_sophistication,
                      boost: 1.2
                    }
                  }
                }
              ]
            : [])
        ],
        minimum_should_match: 0
      }
    },
    sort: [
      '_score',
      {
        'metadata.internal_priority': {
          order: 'desc'
        }
      }
    ]
  };

  try {
    console.log('[OPENSEARCH] Index:', env.OPENSEARCH_APPS_INDEX);
    console.log('[OPENSEARCH] Query:', JSON.stringify(searchBody, null, 2));

    // Use fetch directly for Cloudflare Workers compatibility
    const url = `${client.url}/${env.OPENSEARCH_APPS_INDEX}/_search`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json'
    };

    // Add basic auth if credentials provided
    if (client.username && client.password) {
      const auth = btoa(`${client.username}:${client.password}`);
      headers['Authorization'] = `Basic ${auth}`;
    }

    const fetchResponse = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(searchBody)
    });

    console.log('[OPENSEARCH] Response status:', fetchResponse.status);

    if (!fetchResponse.ok) {
      const errorText = await fetchResponse.text();
      console.error('[OPENSEARCH] Error response:', errorText);
      return [];
    }

    const response = await fetchResponse.json() as any;
    console.log('[OPENSEARCH] Total hits:', response.hits?.total?.value || 0);

    if (!response.hits || !response.hits.hits) {
      console.log('[OPENSEARCH] No hits found');
      return [];
    }

    const results = response.hits.hits.map((hit: any) => {
      const source: AppCatalogDocument = hit._source;
      return {
        id: source.id,
        title: source.title,
        snippet: source.description.substring(0, 200),
        score: hit._score,
        url: source.cta_url,
        appType: source.complexity
      };
    });

    console.log('[OPENSEARCH] Mapped results:', results.length);
    return results;
  } catch (error) {
    console.error('[OPENSEARCH] Error:', error);
    return [];
  }
}

/**
 * Index a new app document (for setup/admin use)
 */
export async function indexApp(
  client: OpenSearchClient,
  env: WorkerEnv,
  app: AppCatalogDocument
): Promise<void> {
  const url = `${client.url}/${env.OPENSEARCH_APPS_INDEX}/_doc/${app.id}?refresh=true`;
  const headers: HeadersInit = {
    'Content-Type': 'application/json'
  };

  if (client.username && client.password) {
    const auth = btoa(`${client.username}:${client.password}`);
    headers['Authorization'] = `Basic ${auth}`;
  }

  const response = await fetch(url, {
    method: 'PUT',
    headers,
    body: JSON.stringify(app)
  });

  if (!response.ok) {
    throw new Error(`Failed to index app: ${response.status}`);
  }
}

/**
 * Create the apps index with proper mapping (for setup)
 */
export async function createAppsIndex(
  client: OpenSearchClient,
  env: WorkerEnv
): Promise<void> {
  const headers: HeadersInit = {
    'Content-Type': 'application/json'
  };

  if (client.username && client.password) {
    const auth = btoa(`${client.username}:${client.password}`);
    headers['Authorization'] = `Basic ${auth}`;
  }

  // Check if index exists
  const existsResponse = await fetch(`${client.url}/${env.OPENSEARCH_APPS_INDEX}`, {
    method: 'HEAD',
    headers
  });

  if (existsResponse.ok) {
    console.log(`Index ${env.OPENSEARCH_APPS_INDEX} already exists`);
    return;
  }

  // Create index
  const createResponse = await fetch(`${client.url}/${env.OPENSEARCH_APPS_INDEX}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({
      mappings: {
        properties: {
          id: { type: 'keyword' },
          title: { type: 'text' },
          description: { type: 'text' },
          use_case_tags: { type: 'keyword' },
          industry_tags: { type: 'keyword' },
          persona_tags: { type: 'keyword' },
          complexity: { type: 'keyword' },
          time_to_value: { type: 'keyword' },
          cta_url: { type: 'keyword' },
          metadata: {
            properties: {
              internal_priority: { type: 'float' }
            }
          }
        }
      }
    })
  });

  if (!createResponse.ok) {
    throw new Error(`Failed to create index: ${createResponse.status}`);
  }

  console.log(`Created index ${env.OPENSEARCH_APPS_INDEX}`);
}
