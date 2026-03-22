{ ... }:
{
  programs.opencode.skills.direnv = ''
    ---
    name: direnv
    description: Work with direnv, nix or flake
    ---

    A project that has `.envrc` often refers to `flake.nix` and/or `.envrc.local`. These files are automatically watched for changes and changes to these files are automatically loaded in your environment.

    When you need to install packages, add them to flake.nix and they will be automatically available after writing.

    When you need environment variables availeble during development (like `JAVA_HOME` or `PYTHONPATH`), you can add them to `devShells.default` in `flake.nix`, `.envrc` or `.envrc.local`.
  '';
}
