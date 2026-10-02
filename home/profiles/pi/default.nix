{
  config,
  impurity,
  lib,
  pkgs,
  ...
}:
let
  piConfigDir = config.programs.pi-coding-agent.configDir;
  subagentWorktreeSetup = pkgs.writeShellApplication {
    name = "pi-subagent-worktree-setup";
    runtimeInputs = [ pkgs.direnv ];
    text = ''
      unset DIRENV_DIR DIRENV_FILE
      direnv allow
      printf '%s\n' '{"syntheticPaths":[]}'
    '';
  };

  extensionFiles = lib.filterAttrs (
    name: type: (type == "regular" && lib.hasSuffix ".ts" name) || type == "directory"
  ) (builtins.readDir ./extensions);
  extensionFileLinks = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${piConfigDir}/extensions/${name}" {
      source = impurity.link (./extensions + "/${name}");
    }
  ) extensionFiles;

  skillFiles = lib.filterAttrs (
    name: type: (type == "regular" && lib.hasSuffix ".md" name) || type == "directory"
  ) (builtins.readDir ./skills);
  skillFileLinks = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${piConfigDir}/skills/${name}" {
      source = impurity.link (./skills + "/${name}");
    }
  ) skillFiles;

  piModels = {
    providers = {
      "llama.cpp" = {
        baseUrl = "http://127.0.0.1:8080/v1";
        api = "openai-completions";
        apiKey = "llama.cpp";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
          supportsUsageInStreaming = false;
          maxTokensField = "max_tokens";
        };
        models = [
          {
            id = "qwen3:14b";
            name = "Qwen3 14B Q4_K_M local";
            contextWindow = 16384;
            maxTokens = 4096;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
          }
        ];
      };

      colibri = {
        baseUrl = "http://127.0.0.1:8081/v1";
        api = "openai-completions";
        apiKey = "local";
        models = [
          {
            id = "glm-5.2-colibri";
            name = "GLM-5.2 via Colibri";
            reasoning = true;
            input = [ "text" ];
            contextWindow = 32768;
            maxTokens = 4096;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
          }
        ];
      };
    };
  };
in
{
  home.file =
    extensionFileLinks
    // skillFileLinks
    // {
      "${piConfigDir}/models.json" = {
        force = true;
        text = builtins.toJSON piModels;
      };
    };

  imports = [
    ./lsp.nix
    ./mcp.nix
    ./subagent.nix
  ];

  programs.pi-coding-agent = {
    enable = true;
    enableMcpIntegration = lib.mkDefault true;
    lsp.settings = {
      languages = {
        typescript = {
          command = "tsc";
          args = [
            "--lsp"
            "--stdio"
          ];
        };
        kotlin.command = "${pkgs.kmp-lsp}/bin/kmp-lsp";
      };
      extensions = {
        ".ts" = "typescript";
        ".tsx" = "typescript";
        ".mts" = "typescript";
        ".cts" = "typescript";
        ".kt" = "kotlin";
      };
    };

    mcp = {
      enable = lib.mkDefault true;
      mcpServers = {
        slite = {
          url = "https://api.slite.com/mcp";
          lifecycle = "lazy";
          auth = "oauth";
        };
      };
    };
    subagent.settings = {
      scheduledRuns.storeRoot = "~/.local/share/pi/subagents/schedules";
      worktreeSetupHook = "${subagentWorktreeSetup}/bin/pi-subagent-worktree-setup";
    };
    package = pkgs.pi;

    extraPackages = [
      pkgs.python3
      pkgs.nodejs
      pkgs.git
      pkgs.ripgrep
      pkgs.direnv
      pkgs.systemd
      pkgs.hyprland
      pkgs.coin
      pkgs.hypr-notify
    ];

    settings = {
      lastChangelogVersion = "0.80.2";
      collapseChangelog = true;
      enableAnalytics = false;
      enableInstallTelemetry = false;
      quietStartup = true;
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-terra";
      defaultThinkingLevel = "medium";
      npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
      subagents.defaultSubagentOnlyExtensions = [ "${piConfigDir}/extensions/direnv.ts" ];
      packages = [
        "npm:@earendil-works/pi-coding-agent@0.84.4"
        "npm:pi-subagents@0.70.1"
        "npm:pi-web-access"
        "npm:remote-pi"
        "npm:@ayulab/pi-rewind"
        "pi-lens"
      ];
    };

    context = impurity.link ./AGENTS.md;

  };
}
