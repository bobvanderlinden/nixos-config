{
  lib,
  stdenv,
  writeTextFile,
  runtimeShell,
  iptables,
}:
writeTextFile rec {
  name = "disable-firewall";
  executable = true;
  destination = "/bin/${name}";
  text = ''
    #!${runtimeShell}
    ${iptables}/bin/iptables -X
    ${iptables}/bin/iptables -t nat -F
    ${iptables}/bin/iptables -t nat -X
    ${iptables}/bin/iptables -t mangle -F
    ${iptables}/bin/iptables -t mangle -X
    ${iptables}/bin/iptables -P INPUT ACCEPT
    ${iptables}/bin/iptables -P OUTPUT ACCEPT
    ${iptables}/bin/iptables -P FORWARD ACCEPT
  '';
  checkPhase = ''
    ${stdenv.shellDryRun} "$target"
  '';
  meta = with lib; {
    platforms = platforms.linux;
  };
}
