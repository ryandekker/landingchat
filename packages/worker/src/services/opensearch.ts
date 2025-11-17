/**
 * OpenSearch service for searching the apps catalog
 */

import { Client } from '@opensearch-project/opensearch';
import type {
  UserProfile,
  SearchResultSummary,
  WorkerEnv,
  AppCatalogDocument
} from '@landingchat/shared';

/**
 * Create OpenSearch client from environment
 */
export function createOpenSearchClient(env: WorkerEnv): Client {
  return new Client({
    node: env.OPENSEARCH_URL,
    auth: {
      username: env.OPENSEARCH_USERNAME,
      password: env.OPENSEARCH_PASSWORD
    },
    ssl: {
      rejectUnauthorized: true
    }
  });
}

/**
 * Search apps catalog based on queries and user profile
 */
export async function searchApps(
  client: Client,
  env: WorkerEnv,
  profile: UserProfile,
  queries: string[]
): Promise<SearchResultSummary[]> {
  if (queries.length === 0) {
    return [];
  }

  // Build the search query
  const searchQuery = {
    index: env.OPENSEARCH_APPS_INDEX,
    body: {
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
              : []),
            // Boost by internal priority
            {
              function_score: {
                field_value_factor: {
                  field: 'metadata.internal_priority',
                  factor: 1.5,
                  modifier: 'sqrt',
                  missing: 0.5
                }
              }
            }
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
    }
  };

  try {
    const response = await client.search(searchQuery);

    if (!response.body.hits || !response.body.hits.hits) {
      return [];
    }

    return response.body.hits.hits.map((hit: any) => {
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
  } catch (error) {
    console.error('OpenSearch error:', error);
    return [];
  }
}

/**
 * Index a new app document (for setup/admin use)
 */
export async function indexApp(
  client: Client,
  env: WorkerEnv,
  app: AppCatalogDocument
): Promise<void> {
  await client.index({
    index: env.OPENSEARCH_APPS_INDEX,
    id: app.id,
    body: app,
    refresh: true
  });
}

/**
 * Create the apps index with proper mapping (for setup)
 */
export async function createAppsIndex(
  client: Client,
  env: WorkerEnv
): Promise<void> {
  const indexExists = await client.indices.exists({
    index: env.OPENSEARCH_APPS_INDEX
  });

  if (indexExists.body) {
    console.log(`Index ${env.OPENSEARCH_APPS_INDEX} already exists`);
    return;
  }

  await client.indices.create({
    index: env.OPENSEARCH_APPS_INDEX,
    body: {
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
    }
  });

  console.log(`Created index ${env.OPENSEARCH_APPS_INDEX}`);
}
