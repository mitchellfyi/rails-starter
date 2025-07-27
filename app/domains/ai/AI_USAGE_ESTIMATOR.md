# AI Usage Simulator & Planner

The AI Usage Simulator & Planner allows you to estimate token usage and costs before running large AI jobs, providing budget control and cost transparency.

## Features

### Single Estimation
- Estimate token usage and costs for individual prompts
- Support for multiple AI models (GPT-4, GPT-3.5-turbo, Claude, Cohere)
- Context variable interpolation
- Multiple output formats (text, JSON, markdown, HTML)
- Real-time cost breakdown with pricing details

### Batch Estimation
- Process multiple inputs at once (up to 1,000 items)
- CSV and JSON file upload support
- Manual JSON array input
- Aggregate cost summaries and per-item breakdowns
- Export results to CSV
- Bulk job execution from estimations

### Cost Transparency
- Input token estimation based on prompt content
- Output token estimation based on format and model
- Provider-specific pricing (OpenAI, Anthropic, Cohere)
- Detailed cost breakdown showing input/output costs separately
- Average cost per input for batch operations

## Usage

### Web Interface

1. **Navigate to the Estimator**
   - Go to `/ai_usage_estimator` or use the navigation link from LLM Outputs

2. **Single Estimation**
   - Select an AI model
   - Enter your prompt template with `{{variable}}` placeholders
   - Provide context variables as JSON
   - Choose output format
   - Click "Estimate Usage" to see cost breakdown

3. **Batch Estimation**
   - Switch to the "Batch Estimation" tab
   - Upload a CSV/JSON file or enter JSON array manually
   - Each row/object becomes context for one estimation
   - View aggregate costs and individual breakdowns
   - Export results or run all jobs

### API Access

The estimator provides JSON:API compliant endpoints:

#### Single Estimation
```bash
POST /api/v1/ai_usage_estimator/estimate
Content-Type: application/json

{
  "data": {
    "type": "ai_usage_estimation",
    "attributes": {
      "template": "Summarize: {{content}}",
      "model": "gpt-3.5-turbo",
      "context": {"content": "Your text here"},
      "format": "text"
    }
  }
}
```

#### Batch Estimation
```bash
POST /api/v1/ai_usage_estimator/batch_estimate
Content-Type: application/json

{
  "data": {
    "type": "ai_batch_usage_estimation",
    "attributes": {
      "template": "Summarize: {{content}}",
      "model": "gpt-3.5-turbo",
      "inputs": [
        {"content": "First document"},
        {"content": "Second document"}
      ],
      "format": "text"
    }
  }
}
```

#### Available Models
```bash
GET /api/v1/ai_usage_estimator/models
```

## File Formats

### CSV Format
```csv
name,content,style
"John","Hello world","formal"
"Jane","How are you?","casual"
```

### JSON Format
```json
[
  {"name": "John", "content": "Hello world", "style": "formal"},
  {"name": "Jane", "content": "How are you?", "style": "casual"}
]
```

## Integration

### With Existing Jobs
- Estimates integrate with the existing LLMJob system
- Can queue jobs directly from estimation results
- Works with workspace AI credentials for accurate pricing
- Supports all existing LLM providers and models

### Workspace Integration
- Respects workspace-level AI credentials
- Uses workspace-specific pricing when available
- Falls back to default pricing for general estimates

## Pricing Models

Current supported providers and models:

### OpenAI
- GPT-4: $0.03/$0.06 per 1K tokens (input/output)
- GPT-4 Turbo: $0.01/$0.03 per 1K tokens
- GPT-3.5 Turbo: $0.0015/$0.002 per 1K tokens

### Anthropic
- Claude 3 Opus: $0.015/$0.075 per 1K tokens
- Claude 3 Sonnet: $0.003/$0.015 per 1K tokens
- Claude 3 Haiku: $0.00025/$0.00125 per 1K tokens

### Cohere
- Command: $0.0015/$0.002 per 1K tokens
- Command Light: $0.0003/$0.0006 per 1K tokens

*Pricing is configurable and can be updated for workspace-specific rates.*

## Configuration

The estimator uses the existing AI provider and credential system:

1. **AI Providers**: Defined in the `AiProvider` model
2. **Credentials**: Workspace-specific `AiCredential` records
3. **Pricing**: Configurable in `AiUsageEstimatorService::MODEL_PRICING`

## Error Handling

- Graceful handling of invalid templates or context
- File upload validation for supported formats
- Batch size limits (1,000 items max)
- Detailed error messages for API responses
- Fallback pricing for unknown models

## Security

- Authentication required for all endpoints
- Workspace-scoped access control
- File upload size and type restrictions
- Input validation and sanitization