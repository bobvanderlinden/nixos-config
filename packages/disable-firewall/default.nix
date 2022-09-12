{writeShellScriptBin, iptables }:
writeShellScriptBin "disable-firewall" ''
  ${iptables}/bin/iptables -X
  ${iptables}/bin/iptables -t nat -F
  ${iptables}/bin/iptables -t nat -X
  ${iptables}/bin/iptables -t mangle -F
  ${iptables}/bin/iptables -t mangle -X
  ${iptables}/bin/iptables -P INPUT ACCEPT
  ${iptables}/bin/iptables -P OUTPUT ACCEPT
  ${iptables}/bin/iptables -P FORWARD ACCEPT
''
