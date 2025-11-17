/**
 * @landingchat/config - Configuration module
 */

import type { InterviewerConfig } from '@landingchat/shared';
import { defaultRadarDimensions } from './defaults/radar.js';
import { defaultChecklist } from './defaults/checklist.js';
import { buildInterviewerPrompt, defaultGoalText } from './prompts/interviewer.js';

export * from './defaults/radar.js';
export * from './defaults/checklist.js';
export * from './prompts/interviewer.js';

/**
 * Get the default interviewer configuration
 */
export function getDefaultInterviewerConfig(): InterviewerConfig {
  return {
    radarDimensions: defaultRadarDimensions,
    checklist: defaultChecklist,
    goalText: defaultGoalText
  };
}

/**
 * Get the default interviewer prompt
 */
export function getDefaultInterviewerPrompt(): string {
  return buildInterviewerPrompt(getDefaultInterviewerConfig());
}
