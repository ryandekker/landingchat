/**
 * Profile summary component
 */

import type { UserProfile } from '@landingchat/shared';

interface ProfileSummaryProps {
  profile: UserProfile | null;
}

export function ProfileSummary({ profile }: ProfileSummaryProps) {
  if (!profile) {
    return (
      <div className="text-gray-500 text-sm">
        <p>Start chatting to build your profile...</p>
      </div>
    );
  }

  const { attributes, conversation_summary } = profile;

  return (
    <div className="space-y-3">
      <div className="text-sm">
        {conversation_summary.summary_text && (
          <div className="mb-3 p-3 bg-blue-50 rounded-lg">
            <p className="text-gray-700">{conversation_summary.summary_text}</p>
          </div>
        )}

        {Object.entries(attributes).length > 0 && (
          <ul className="space-y-2">
            {attributes.industry && (
              <li className="flex items-start">
                <span className="font-semibold mr-2">Industry:</span>
                <span className="text-gray-700">{attributes.industry}</span>
              </li>
            )}
            {attributes.role && (
              <li className="flex items-start">
                <span className="font-semibold mr-2">Role:</span>
                <span className="text-gray-700">{attributes.role}</span>
              </li>
            )}
            {attributes.company_size && (
              <li className="flex items-start">
                <span className="font-semibold mr-2">Company Size:</span>
                <span className="text-gray-700">{attributes.company_size}</span>
              </li>
            )}
            {attributes.main_pain_point && (
              <li className="flex items-start">
                <span className="font-semibold mr-2">Pain Point:</span>
                <span className="text-gray-700">{attributes.main_pain_point}</span>
              </li>
            )}
            {attributes.timeframe && (
              <li className="flex items-start">
                <span className="font-semibold mr-2">Timeline:</span>
                <span className="text-gray-700">{attributes.timeframe}</span>
              </li>
            )}
          </ul>
        )}

        {conversation_summary.answered_questions.length > 0 && (
          <div className="mt-3 pt-3 border-t border-gray-200">
            <p className="text-xs text-gray-500">
              Progress: {conversation_summary.answered_questions.length} of{' '}
              {conversation_summary.answered_questions.length + conversation_summary.remaining_questions.length}{' '}
              questions answered
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
