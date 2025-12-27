{
  claude = {
    config,
    pkgs,
    sensitive,
    ...
  }: {
    sops.secrets."one2x/llmToken" = {};
    home.file.".local/bin/one2x-claude" = {
      text = ''
        #!/usr/bin/env bash

        export ANTHROPIC_AUTH_TOKEN="$(cat ${config.sops.secrets."one2x/llmToken".path})"
        export ANTHROPIC_BASE_URL="${sensitive.data.one2x.llmUrl}"
        export ANTHROPIC_DEFAULT_OPUS_MODEL='global.anthropic.claude-opus-4-5-20251101-v1:0'
        export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-5-20250929-v1:0'
        export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-sonnet-4-5-20250929-v1:0'
        export CLAUDE_CODE_SUBAGENT_MODEL='us.anthropic.claude-sonnet-4-5-20250929-v1:0'

        exec bunx @anthropic-ai/claude-code "$@"
      '';
      executable = true;
    };
  };
  gemini = {
    config,
    pkgs,
    sensitive,
    ...
  }: {
    sops.secrets."one2x/llmToken" = {};
    home.file.".local/bin/one2x-gemini" = {
      text = ''
        #!/usr/bin/env bash

        export GEMINI_API_KEY="$(cat ${config.sops.secrets."one2x/llmToken".path})"
        export GOOGLE_GEMINI_BASE_URL="${sensitive.data.one2x.llmUrl}"

        exec bunx @google/gemini-cli "$@"
      '';
      executable = true;
    };
  };
  codex = {
    config,
    pkgs,
    sensitive,
    ...
  }: {
    sops.secrets."one2x/llmToken" = {};
    home.file.".local/bin/one2x-codex" = {
      text = ''
        #!/usr/bin/env bash

        export AZURE_OPENAI_API_KEY="$(cat ${config.sops.secrets."one2x/llmToken".path})"
        exec bunx @openai/codex \
          -c model="azure/gpt-5" \
          -c model_reasoning_effort="high" \
          -c model_provider="azure" \
          -c 'model_providers.azure={name = "Azure", base_url = "${sensitive.data.one2x.llmUrl}", env_key = "AZURE_OPENAI_API_KEY", query_params = {api-version = "2025-04-01-preview"}}' "$@"
      '';
      executable = true;
    };
  };
}
