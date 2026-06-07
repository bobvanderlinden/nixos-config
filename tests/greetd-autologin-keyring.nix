{
  lib,
  pkgs,
  greetdAutologinKeyringModule,
}:
let
  password = "supersecret";

  autologinSession = pkgs.writeShellApplication {
    name = "test-autologin-session";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      touch "''${XDG_RUNTIME_DIR}/autologin-ready"
      exec sleep infinity
    '';
  };

  setupLoginKeyring = pkgs.writeShellApplication {
    name = "setup-login-keyring";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnome-keyring
      pkgs.libsecret
    ];
    text = ''
      eval "$(printf '${password}' | gnome-keyring-daemon --unlock --components=secrets)"
      printf 'storedsecret' | secret-tool store --label='vm-test-secret' service vm-test
    '';
  };

  readLoginKeyring = pkgs.writeShellApplication {
    name = "read-login-keyring";
    runtimeInputs = [ pkgs.libsecret ];
    text = ''
      secret-tool lookup service vm-test
    '';
  };
in
{
  name = "greetd-autologin-keyring";

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [ greetdAutologinKeyringModule ];

      virtualisation = {
        emptyDiskImages = [ 512 ];
        useBootLoader = true;
        mountHostNixStore = true;
        useEFIBoot = true;
      };

      boot.loader.systemd-boot.enable = true;
      boot.initrd.systemd.enable = true;

      users.defaultUserShell = pkgs.bashInteractive;
      users.users.alice = {
        isNormalUser = true;
        password = password;
      };

      services.greetd = {
        enable = true;
        useTextGreeter = true;
        settings = {
          default_session.command = "${pkgs.greetd}/bin/agreety --cmd bash";
          initial_session = {
            user = "alice";
            command = "${autologinSession}/bin/test-autologin-session";
          };
        };
      };

      environment.systemPackages = [
        pkgs.cryptsetup
        pkgs.dbus
        setupLoginKeyring
        readLoginKeyring
      ];

      specialisation.boot-luks.configuration = {
        boot.initrd.luks.devices = lib.mkVMOverride {
          cryptdata.device = "/dev/vdb";
        };

        fileSystems."/cryptdata" = {
          device = "/dev/mapper/cryptdata";
          fsType = "ext4";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("graphical.target")
    machine.wait_for_file("/run/user/1000/autologin-ready")

    with subtest("autologin starts the initial greetd session"):
        machine.succeed("pgrep -u alice -x sleep")

    with subtest("create a login keyring and seed a secret before reboot"):
        machine.succeed("su - alice -c '${pkgs.dbus}/bin/dbus-run-session ${setupLoginKeyring}/bin/setup-login-keyring'")
        machine.wait_for_file("/home/alice/.local/share/keyrings/login.keyring")

    with subtest("prepare a LUKS volume unlocked in the systemd initrd"):
        machine.succeed("echo -n ${password} | cryptsetup luksFormat -q --iter-time=1 /dev/vdb -")
        machine.succeed("echo -n ${password} | cryptsetup luksOpen -q --key-file - /dev/vdb cryptdata")
        machine.succeed("mkfs.ext4 /dev/mapper/cryptdata")
        machine.succeed("cryptsetup close cryptdata")
        machine.succeed("bootctl set-default nixos-generation-1-specialisation-boot-luks.conf")
        machine.succeed("sync")

    machine.crash()

    with subtest("unlock the LUKS volume during boot and autologin again"):
        machine.start()
        machine.wait_for_console_text("Please enter passphrase for disk cryptdata")
        machine.send_console("${password}\n")
        machine.wait_for_unit("graphical.target")
        machine.wait_for_file("/run/user/1000/autologin-ready")

    with subtest("pam_fde_boot_pw unlocks the existing login keyring on autologin"):
        machine.succeed(
            "su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus timeout 10s ${readLoginKeyring}/bin/read-login-keyring'"
        )
  '';
}
