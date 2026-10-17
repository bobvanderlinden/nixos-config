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
    runtimeInputs = [
      pkgs.jq
      pkgs.worktree
    ];
    text = ''
      repository_root="$(jq --raw-output --exit-status '.repoRoot')"
      worktree --prepare "$repository_root" "$PWD"
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
      strata = {
        baseUrl = "http://127.0.0.1:8080/v1";
        api = "openai-completions";
        apiKey = "strata";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = true;
          supportsUsageInStreaming = false;
          maxTokensField = "max_tokens";
        };
        models = [
          {
            id = "qwen3.8-flash-next";
            name = "Qwen3.8-Flash-Next IQ2_XS via Strata";
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
    ./web.nix
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
      enable = false;
      mcpServers = {
        slite = {
          url = "https://api.slite.com/mcp";
          lifecycle = "lazy";
          auth = "oauth";
        };
      };
    };
    subagent.settings = {
      # Our patched native allocator calls worktree for paths and creation.
      # Pi-subagents still owns handoff artifacts and cleanup.
      # Callers can use worktree:false for shared-checkout inspection.
      worktree = true;
      worktreeProvider = "native";
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
      lastChangelogVersion = "1.1.0";
      collapseChangelog = true;
      enableAnalytics = false;
      enableInstallTelemetry = false;
      quietStartup = true;
      tuiMode = "regular";
      outputPad = 0;
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6.1-sol";
      defaultThinkingLevel = "medium";
      defaultTools = [ "+codemode" ];
      npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
      subagents.defaultSubagentOnlyExtensions = [ "${piConfigDir}/extensions/direnv.ts" ];
      packages = [
        "npm:@earendil-works/pi-coding-agent@1.1.0"
        "${pkgs.pi-subagents}/lib/node_modules/pi-subagents"
        "npm:pi-background-tasks@2.6.10"
        "npm:pi-web-access@0.37.0"
        "npm:@ayulab/pi-rewind"
        "npm:@ygncode/pi-web@0.0.1-beta.38"
      ];
    };

    context = impurity.link ./AGENTS.md;

  };
}
