/**
 * Recommendations component
 */

import type { SearchResultSummary } from '@landingchat/shared';

interface RecommendationsProps {
  recommendations: SearchResultSummary[];
}

export function Recommendations({ recommendations }: RecommendationsProps) {
  if (!recommendations || recommendations.length === 0) {
    return null;
  }

  return (
    <div className="space-y-3">
      <h3 className="font-semibold text-sm">Recommended Solutions</h3>
      <div className="space-y-2">
        {recommendations.map((rec) => (
          <div
            key={rec.id}
            className="p-3 bg-white border border-gray-200 rounded-lg hover:border-primary-300 transition-colors"
          >
            <h4 className="font-semibold text-sm text-gray-900">{rec.title}</h4>
            <p className="text-xs text-gray-600 mt-1 line-clamp-2">{rec.snippet}</p>
            {rec.url && (
              <a
                href={rec.url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-primary-600 hover:text-primary-700 mt-2 inline-block"
              >
                Learn more →
              </a>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
