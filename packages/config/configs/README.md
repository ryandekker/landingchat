# Configuration Files

This directory contains JSON configuration files for the LandingChat interviewer system. Each configuration file defines:

- **goalText**: The high-level mission statement for the AI interviewer
- **radarDimensions**: 5-6 dimensions to track understanding (0-100 score, 0-1 confidence)
- **checklist**: Required information items to collect before conversation completion

## Usage

### Using the Default Configuration

By default, the system loads `default.json`:

```typescript
import { getDefaultInterviewerConfig } from '@landingchat/config';
const config = getDefaultInterviewerConfig();
```

### Using a Custom Configuration

Create a new JSON file in this directory (e.g., `my-config.json`) and load it by name:

```typescript
import { getInterviewerConfig } from '@landingchat/config';
const config = getInterviewerConfig('my-config');  // Loads configs/my-config.json
```

### Switching Configurations via Environment Variable

Set the `INTERVIEWER_CONFIG_NAME` environment variable to use a different config:

```bash
# In .dev.vars or wrangler.toml
INTERVIEWER_CONFIG_NAME=example-custom
```

The worker will automatically load `configs/example-custom.json` instead of the default.

### Loading from Absolute Path

You can also load from an absolute path:

```typescript
import { loadConfigFromFile } from '@landingchat/config';
const config = loadConfigFromFile('/path/to/my-config.json');
```

## Configuration Schema

### Structure

```json
{
  "goalText": "string - The AI's mission statement",
  "radarDimensions": [
    {
      "id": "string - unique identifier (e.g., 'goal_clarity')",
      "label": "string - display name",
      "description": "string - what this dimension tracks"
    }
  ],
  "checklist": [
    {
      "id": "string - unique identifier (e.g., 'primary_goal')",
      "label": "string - display name",
      "description": "string - what information to collect"
    }
  ]
}
```

### Guidelines

1. **Radar Dimensions**: Keep to 5-6 dimensions for clarity
   - Each dimension is scored 0-100 with confidence 0.0-1.0
   - Dimensions should represent orthogonal aspects of understanding

2. **Checklist Items**: 5-10 items recommended
   - These are discrete information points to collect
   - The conversation completes when all items are answered
   - Order matters - earlier items are prioritized

3. **Goal Text**: 1-3 sentences
   - Should clearly state the interviewer's purpose
   - Informs the tone and approach of the conversation

## Example Configurations

### default.json
General-purpose configuration for understanding user needs and recommending solutions from an app catalog.

### example-custom.json
Enterprise sales-focused configuration using BANT (Budget, Authority, Need, Timeline) qualification framework.

## Swapping Configurations

To switch between configurations:

1. **During Development**: Change the environment variable in `.dev.vars`
   ```
   INTERVIEWER_CONFIG_NAME=example-custom
   ```

2. **In Production**: Set the environment variable in your Cloudflare Workers settings

3. **Programmatically**: Use `getInterviewerConfig(configName)` directly in your code

4. **Hot Swap**: Create new JSON files and reference them - no code rebuild required!

## Best Practices

- **Version Control**: Keep your config files in git to track changes
- **Testing**: Test new configurations thoroughly before production use
- **Naming**: Use descriptive names (e.g., `enterprise-sales.json`, `support-triage.json`)
- **Documentation**: Add comments in a separate README or inline in your code
- **Validation**: The TypeScript types ensure your JSON matches the expected schema

## Troubleshooting

If a config file fails to load:

1. Check that the file exists in `packages/config/configs/`
2. Verify the JSON is valid (no trailing commas, proper quotes)
3. Ensure all required fields are present (goalText, radarDimensions, checklist)
4. Check that dimension and checklist IDs are unique strings
5. Review the console/logs for specific error messages
