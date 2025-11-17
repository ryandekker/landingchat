/**
 * Default radar dimension configurations
 *
 * These dimensions define what the system tracks about the user's understanding
 * and readiness. Maximum of 5-6 dimensions recommended for clarity.
 */

import type { RadarDimensionConfig } from '@landingchat/shared';

export const defaultRadarDimensions: RadarDimensionConfig[] = [
  {
    id: 'goal_clarity',
    label: 'Goal Clarity',
    description: 'How well we understand the user\'s primary objective and what they want to achieve'
  },
  {
    id: 'use_case_specificity',
    label: 'Use Case Specificity',
    description: 'How specific and concrete the user\'s use case or scenario is'
  },
  {
    id: 'technical_context',
    label: 'Technical Context',
    description: 'Understanding of the user\'s technical sophistication and existing infrastructure'
  },
  {
    id: 'business_context',
    label: 'Business Context',
    description: 'Understanding of industry, company size, role, and organizational constraints'
  },
  {
    id: 'urgency_timeline',
    label: 'Urgency & Timeline',
    description: 'How urgent the need is and what timeline the user is working within'
  },
  {
    id: 'budget_constraints',
    label: 'Budget Constraints',
    description: 'Understanding of budget expectations and financial constraints'
  }
];
