/**
 * @landingchat/config - Configuration module
 */

import type { InterviewerConfig } from '@landingchat/shared';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { buildInterviewerPrompt } from './prompts/interviewer.js';

// Keep exports for backward compatibility
export * from './defaults/radar.js';
export * from './defaults/checklist.js';
export * from './prompts/interviewer.js';

// Get the directory of the current module
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Load configuration from a JSON file
 */
export function loadConfigFromFile(configPath: string): InterviewerConfig {
  const absolutePath = configPath.startsWith('/')
    ? configPath
    : join(__dirname, '..', configPath);

  const configData = readFileSync(absolutePath, 'utf-8');
  return JSON.parse(configData) as InterviewerConfig;
}

/**
 * Get the default interviewer configuration (loaded from JSON)
 */
export function getDefaultInterviewerConfig(): InterviewerConfig {
  return loadConfigFromFile('configs/default.json');
}

/**
 * Get a custom interviewer configuration by name
 * @param configName - Name of the config file (without .json extension)
 */
export function getInterviewerConfig(configName: string = 'default'): InterviewerConfig {
  return loadConfigFromFile(`configs/${configName}.json`);
}

/**
 * Get the default interviewer prompt
 */
export function getDefaultInterviewerPrompt(): string {
  return buildInterviewerPrompt(getDefaultInterviewerConfig());
}

/**
 * Get a custom interviewer prompt by config name
 * @param configName - Name of the config file (without .json extension)
 */
export function getInterviewerPrompt(configName: string = 'default'): string {
  return buildInterviewerPrompt(getInterviewerConfig(configName));
}
