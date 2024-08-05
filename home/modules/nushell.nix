{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.programs.nushell;
  formatNuValue =
    let
      indentation = "  ";
      indent =
        str:
        let
          lines = splitString "\n" str;
          indentedLines = map (line: "${indentation}${line}") lines;
        in
        lib.concatStringsSep "\n" indentedLines;
    in
    value:
    {
      bool = v: if v then "true" else "false";
      int = toString;
      float = toString;
      string = builtins.toJSON;
      null = v: "null";
      path = v: formatNuValue (toString v);
      list = v: "[${lib.concatStrings (map (v: "\n${indent (formatNuValue v)}") v)}\n]";
      set =
        v:
        if nuExpressionType.check v then
          v.__nu
        else
          "{${lib.concatStrings (mapAttrsToList (k: v: "\n${indent "${k}: ${formatNuValue v}"}") v)}\n}";
    }
    .${builtins.typeOf value}
    value;

  nuExpressionType = mkOptionType {
    name = "nu";
    description = "Nu expression";
    check = x: isAttrs x && x ? __nu && isString x.__nu;
    merge = mergeEqualOption;
  };
in
{
  meta.maintainers = [ maintainers.bobvanderlinden ];

  options = {
    programs.nushell = {
      settingss = mkOption {
        type =
          with lib.types;
          let
            valueType =
              nullOr (oneOf [
                nuExpressionType
                bool
                int
                float
                str
                path
                (attrsOf valueType)
                (listOf valueType)
              ])
              // {
                description = "Nu value type";
              };
          in
          valueType;
        default = { };
        example = literalExpression ''
          {
            show_banner = false;
          }
        '';
        description = ''
          Configuration written to
          <filename>$XDG_CONFIG_HOME/pueue/pueue.yml</filename>.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.nushell.extraConfig = mkBefore ''
        let-env config = ${formatNuValue cfg.settingss}
      '';
    }
    {
      programs.nushell.extraConfig = mkAfter (
        lib.concatLines (
          mapAttrsToList (k: v: ''
            alias ${k} = ${v}                         
          '') cfg.shellAliases
        )
      );
    }
  ]);
}
