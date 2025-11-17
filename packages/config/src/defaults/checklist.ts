/**
 * Default conversation checklist
 *
 * This checklist defines the required information to collect before the
 * conversation is considered "complete". The LLM must track which items
 * have been answered and when all items are answered, the conversation
 * should transition to wrap-up and recommendations.
 */

import type { ChecklistItem } from '@landingchat/shared';

export const defaultChecklist: ChecklistItem[] = [
  {
    id: 'primary_goal',
    label: 'Primary Goal',
    description: 'What is the user trying to accomplish? What problem are they trying to solve?'
  },
  {
    id: 'current_situation',
    label: 'Current Situation',
    description: 'What is the user currently doing? What\'s not working? What manual processes exist?'
  },
  {
    id: 'industry_role',
    label: 'Industry & Role',
    description: 'What industry does the user work in? What is their role?'
  },
  {
    id: 'company_size',
    label: 'Company Size',
    description: 'How large is the organization? (solo, small team, mid-size, enterprise)'
  },
  {
    id: 'technical_level',
    label: 'Technical Sophistication',
    description: 'What is the user\'s technical comfort level? Do they have developer resources?'
  },
  {
    id: 'timeline',
    label: 'Timeline',
    description: 'When does the user need a solution? How urgent is this?'
  },
  {
    id: 'budget_awareness',
    label: 'Budget Awareness',
    description: 'What is the user\'s budget range or price sensitivity? (optional but helpful)'
  },
  {
    id: 'success_criteria',
    label: 'Success Criteria',
    description: 'How will the user know if a solution is working? What does success look like?'
  }
];
