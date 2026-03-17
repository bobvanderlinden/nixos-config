{ pkgs, ... }:
{
  home.packages = [
    pkgs.generate-secret
    pkgs.generate-password
  ];

  programs.opencode.skills.secrets = ''
    ---
    name: secrets
    description: Create and manage secrets like API tokens or passwords
    ---

    Avoid looking at secrets.
    Prefer piping generated secrets to storage or commands that consume them
    Prefer piping over shell variables
    Prefer shell variables over files

    Use `generate-password` for human-readable passwords
    Use `generate-secret` for machine tokens and API keys

    These generated secrets are shown to you as `[REDACTED]` to avoid leakage

    ## Examples

    ```
    generate-secret | kubeseal --raw --from-file=/dev/stdin ...
    ```

    ```
    generate-password | yq '.user.password = load_str("/dev/stdin")' -i config.yaml
    ```

    When I need to know about a new secret, create a new file:

    ```
    (umask 077 && generate-secret > ~/.secrets/new_secret)
    ```

    ```
    op read op://some-vault/some-secret/password | ...
    ```
  '';
}
