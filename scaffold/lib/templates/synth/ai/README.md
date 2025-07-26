# AI Module

This module adds first‑class AI integration to your Rails app. It installs prompt templates, an LLM job runner, and context providers for multi‑context prompts.

## Installation

Run the following command from your application root to install the AI module via the Synth CLI:

```
bin/synth add ai
```

This command will add the necessary gems, copy configuration files, run migrations, and set up initial prompt templates.

## Customisation

The AI module ships with sensible defaults but is designed for extension. Review `install.rb` for details on what is installed. You can customise prompt templates, LLM models, and context fetchers by editing the generated files in your application.

## Next steps

After installation, configure your OpenAI or other LLM API keys in the appropriate credentials file. Run the test suite to ensure the AI components are functioning as expected:

```
bin/synth test ai
```

Contributions and improvements are welcome. Keep this README up to date as the module evolves.
