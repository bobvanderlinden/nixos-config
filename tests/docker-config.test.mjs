import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const repositoryPath = fileURLToPath(new URL("../", import.meta.url));
const expression = `
  let
    flake = builtins.getFlake ${JSON.stringify(repositoryPath)};
    inspect = configuration: {
      rootfulEnabled = configuration.config.virtualisation.docker.enable;
      rootlessEnabled = configuration.config.virtualisation.docker.rootless.enable;
      setSocketVariable = configuration.config.virtualisation.docker.rootless.setSocketVariable;
      settings = configuration.config.virtualisation.docker.rootless.daemon.settings;
      execStart = configuration.config.systemd.user.services.docker.serviceConfig.ExecStart;
      hasSystemService = configuration.config.systemd.services ? docker;
      trustedInterfaces = configuration.config.networking.firewall.trustedInterfaces;
      userGroups = (builtins.getAttr configuration.config.suites.single-user.user
        configuration.config.users.users).extraGroups;
      hasCustomOptions = configuration.options.virtualisation ? dockerConfig
        || configuration.options.virtualisation.docker ? daemonConfig
        || configuration.options.virtualisation.docker ? ipv6;
    };
  in {
    hasCustomModule = flake.nixosModules ? docker-config;
    hosts = builtins.mapAttrs (hostname: configuration: {
      enabled = inspect configuration;
      disabled = inspect (configuration.extendModules {
        modules = [ ({ lib, ... }: { networking.enableIPv6 = lib.mkForce false; }) ];
      });
    }) flake.nixosConfigurations;
  }
`;

// Evaluate Docker configuration and its service command, never build or activate.
const evaluated = JSON.parse(execFileSync("nix", [
  "eval", "--impure", "--json", "--expr", expression,
], { cwd: repositoryPath, encoding: "utf8", timeout: 90_000 }));

test("obsolete Docker module is no longer exported", () => {
  assert.equal(evaluated.hasCustomModule, false);
});

for (const [hostname, configurations] of Object.entries(evaluated.hosts)) {
  for (const [mode, configuration] of Object.entries(configurations)) {
    test(`${hostname}: rootless Docker is configured with IPv6 ${mode}`, () => {
      assert.equal(configuration.hasCustomOptions, false);
      assert.equal(configuration.rootfulEnabled, false);
      assert.equal(configuration.rootlessEnabled, true);
      assert.equal(configuration.setSocketVariable, true);
      assert.equal(configuration.hasSystemService, false);
      assert.equal(configuration.userGroups.includes("docker"), false);
      assert.equal(configuration.trustedInterfaces.includes("docker0"), false);
      const command = [configuration.execStart].flat().join("\n");
      assert.match(command, /\/dockerd-rootless\b/);
      assert.equal((command.match(/--config-file\b/g) ?? []).length, 1);
      if (mode === "enabled") {
        assert.equal(configuration.settings.ipv6, true);
        assert.equal(configuration.settings["fixed-cidr-v6"], "fd00::/80");
      } else {
        assert.equal(Object.hasOwn(configuration.settings, "ipv6"), false);
        assert.equal(Object.hasOwn(configuration.settings, "fixed-cidr-v6"), false);
      }
    });
  }
}
