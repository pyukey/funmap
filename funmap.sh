#!/bin/bash
if [ -d fun ]; then
  rm -rf fun
else
  :
fi
mkdir fun
cd fun
 
echo "Enter a subnet to scan"
 
regex='^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$'
read sub
while [[ $sub =~ $regex ]]; do
  echo "$sub" >> subnets
  echo "Enter a subnet to scan. [Type done to stop]"
  read sub
done
while read -r sub; do
  subStart=${sub%%/*}
  mkdir "$subStart"
  cd "$subStart"
  nmap -PR -PE -PP -PM -PO2 -PS21,22,23,25,80,110,113,135,137,143,443,445,691,993,995,1433,1521,2483,2484,3306,8008,8080,8443,7680,31339 -PA80,113,443,10042 -sn "$sub" | grep report | awk '{print $5" "$6}' > hosts.txt
  sed -i -E 's/^(\S+)\s+.(.*).$/\2 /' hosts.txt
  while read -r host; do
    ip=$(echo "$host" | awk '{print $1}')
    nmap -sS -sV "$ip" > "$ip" 2>/dev/null &
  done < hosts.txt
  sed -i 's|$|Kali assets/Kali ssh,rdp|' hosts.txt
  cd ..
done < subnets
 
# Reformat hosts.txt to be IP, hostname, distro, services
 
cat ../index.template.html > ../index.html
ybase=25
while read -r sub; do
  subStart=${sub%%/*}
  cd "$subStart"
  lines=$(wc -l < hosts.txt)
  ((lines -= 2))
  router=$(head -1 hosts.txt | awk '{print $1}')
  xbase=0
  ycur=$ybase
 
  count=0
 
  while read -r ip hostname distro services ; do
    if [ "$ip" = "$router" ]; then
      echo "{ data: { id: \"$ip\", label: \"$ip\n$hostname\", image: \"$distro.png\" }, classes: \"router\", position: { x: 56, y: $((ycur-25)) } }," >> ../../index.html
    else
      echo "{ data: { id: \"$ip\", label: \"$ip\n$hostname\", image: \"$distro.png\" }, position: { x: $xbase, y: $ybase } }," >> ../../index.html
      echo "{ data: { id: \"connect.$ip\", source: \"$router\", target: \"$ip\" } }," >> ../../index.html
      ((count += 1))
      if [ "$count" -eq 8 ]; then
        count=0
        ((lines -= 8))
        if ((lines < 8)); then
          ((xbase=8*(7-lines)))
        else
          xbase=0
        fi
        ((ybase += 25))
      else
        ((xbase += 16))
      fi
    fi
  done < hosts.txt
  cd ..
  ((ybase += 10))
done < subnets
cd ..
echo "]});" >> index.html
echo "</script>" >> index.html
echo "</body>" >> index.html
echo "</html>" >> index.html
