{
  config,
  lib,
  pkgs,
  ...
}:
let
  piConfig = config.programs.pi-coding-agent;
  cfg = piConfig.mcp;
  json = pkgs.formats.json { };

  isSharedServerEnabled =
    server:
    !(server.disabled or false) && (!(server ? enabled) || server.enabled == null || server.enabled);

  transformEnvValue =
    value: if builtins.isAttrs value && value ? file then "{file:${value.file}}" else value;

  transformSharedServer =
    server:
    let
      cleanServer = lib.filterAttrs (_optionName: value: value != null) (
        builtins.removeAttrs server [
          "disabled"
          "enabled"
        ]
      );
    in
    if server ? url && server.url != null then
      cleanServer
      // {
        transport = server.transport or "streamable-http";
      }
    else
      cleanServer
      // {
        transport = server.transport or "stdio";
      }
      // lib.optionalAttrs (server ? env) {
        env = lib.mapAttrs (_name: transformEnvValue) server.env;
      };

  sharedMcpServers = lib.optionalAttrs (piConfig.enableMcpIntegration && config.programs.mcp.enable) (
    lib.mapAttrs (_name: transformSharedServer) (
      lib.filterAttrs (_name: isSharedServerEnabled) config.programs.mcp.servers
    )
  );

  mergedMcpServers = sharedMcpServers // cfg.mcpServers;

  mcpConfig = {
    inherit (cfg) settings;
    mcpServers = mergedMcpServers;
  };
in
{
  options.programs.pi-coding-agent = {
    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to integrate MCP servers from {option}`programs.mcp.servers`
        into Pi's {file}`mcp.json` for pi-mcp-extension.

        Note: Settings defined in {option}`programs.pi-coding-agent.mcp.mcpServers`
        are merged with {option}`programs.mcp.servers`, with Pi-specific
        settings taking precedence.
      '';
    };

    mcp = {
      enable = lib.mkEnableOption "Pi MCP extension integration";

      settings = lib.mkOption {
        type = json.type;
        default = { };
        example = {
          toolPrefix = "mcp";
          requestTimeoutMs = 30000;
          maxRetries = 5;
        };
        description = ''
          Global settings written to Pi's {file}`mcp.json` for pi-mcp-extension.
        '';
      };

      mcpServers = lib.mkOption {
        type = lib.types.attrsOf json.type;
        default = { };
        example = {
          context7 = {
            command = "npx";
            args = [
              "-y"
              "@context7/mcp"
            ];
            transport = "stdio";
            lifecycle = "lazy";
          };
        };
        description = ''
          Pi-specific MCP servers written under Pi's {file}`mcp.json` for
          pi-mcp-extension.

          Shared MCP servers should usually be defined in
          {option}`programs.mcp.servers` and enabled for Pi with
          {option}`programs.pi-coding-agent.enableMcpIntegration`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi-coding-agent.settings.packages = lib.mkIf piConfig.enable [
      "npm:pi-mcp-extension"
    ];

    home.file."${piConfig.configDir}/mcp.json" = lib.mkIf piConfig.enable {
      source = json.generate "pi-mcp.json" mcpConfig;
    };
  };
}
