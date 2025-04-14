#!/bin/bash
./install.sh
 
path="$(pwd)"
 
if [ -f pass.txt ]; then
  rm pass.txt
fi
 
if [ -f users.txt ]; then
  rm users.txt
fi
 
if [ -d fun ]; then
  rm -rf fun
fi
mkdir fun
cd fun
 
crack() {
  ip="$1"
  put="$(sshpass -p pass ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no user@$1 'hostname; uname -a' 2>&1 | grep 'Connection')"
  if [[ -n "$put" ]]; then
    return
  fi
  while read -r user; do
    while read -r pass; do
      output="$(sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$1 'hostname; uname -a' 2>&1 | grep -v 'denied\|closed\|reset' | sed ':a;N;$!ba;s/\n/|/g' | grep -v hostname)"
      if [[ -n "$output" ]]; then
        name="$(echo $output | awk -F'|' '{print $1}')"
        uname="$(echo $output | awk -F'|' '{print $2}')"
        if echo "$uname" | grep -qi debian; then
          distro="Debian"
        elif echo "$uname" | grep -qi ubuntu; then
          distro="Ubuntu"
        elif echo "$uname" | grep -qi kali; then
          distro="Kali"
        elif echo "$uname" | grep -qi rhel; then
          distro="RHEL"
        elif echo "$uname" | grep -qi centos; then
          distro="CentOS"
        elif echo "$uname" | grep -qi fedora; then
          distro="Fedora"
        elif echo "$uname" | grep -qi rocky; then
          distro="Rocky"
        elif echo "$uname" | grep -qi alma; then
          distro="Alma"
        elif echo "$uname" | grep -qi arch; then
          distro="Arch"
        elif echo "$uname" | grep -qi manjaro; then
          distro="Manjaro"
        elif echo "$uname" | grep -qi endeavour; then
          distro="Endeavour"
        elif echo "$uname" | grep -qi alpine; then
          distro="Alpine"
        elif echo "$uname" | grep -qi nixos; then
          distro="NixOS"
        elif echo "$uname" | grep -qi freebsd; then
          distro="FreeBSD"
        elif echo "$uname" | grep -qi openbsd; then
          distro="OpenBSD"
        elif echo "$uname" | grep -qi netbsd; then
          distro="NetBSD"
        elif echo "$uname" | grep -qi dragonfly; then
          distro="DragonFly"
        else
          distro="WindowsXP"
        fi
        echo "$ip:$user:$pass" >> crack.txt
        sed -i "/$ip/s/ unknown WindowsXP/ $name $distro/" hosts.txt
        return
      fi
    done < "$path/pass.txt"
  done < "$path/users.txt"
  cp crack.txt creds.txt
}

makeJSON() {
  printf "{\n  \"properties\": {\n    \"ip\": \"$1\",\n    \"hostname\": \"$2\",\n    \"distro\": \"$3\"\n  },\n  \"services\": [\n"
  grep open "$1/nmap.txt" | awk '{print "    {\n      \"name\": \""$3"\",\n      \"port\": \""$1"\",\n      \"version\": \""$4"\"\n    },"}' | sed '$ s/.$//'
  printf "  ],\n  \"defaultCreds\": {\n"
  if grep -q "$1:" crack.txt; then
    grep "$1:" crack.txt | awk -F: '{print "    \"user\": \""$2"\",\n    \"passwd\": \""$3"\""}'
  else
    printf "    \"user\": \"N/A\",\n    \"passwd\": \"N/A\"\n"
  fi
  printf "  }\n}"
}

read -p "Enter default user: " user
while true; do
  if [ "$user" = "done" ]; then
    break
  else
    echo "$user" >> "$path/users.txt"
  fi
  read -p "Enter default user. [Type done to stop]: " user
done
 
read -p "Enter default password: " pass
while true; do
  if [ "$pass" = "done" ]; then
    break
  else
    echo "$pass" >> "$path/pass.txt"
  fi
  read -p "Enter default password. [Type done to stop]: " pass
done 

mkdir "1.1.1.1"
cd "1.1.1.1"

regex='^([0-9]{1,3}\.){3}[0-9]{1,3})$'
read -p "Enter an ip to scan: " ip
while [[ $ip =~ $regex ]]; do
    echo "$ip" >> hosts.txt
    mkdir "$ip"
    nmap -sS -sV "$ip" > "$ip/nmap.txt" 2>/dev/null &
  read -p "Enter a subnet to scan. [Type done to stop]: " ip
done
 
echo "Let's go!"
 
cat ../index.template.html > ../index.html
ybase=25
while read -r sub; do
  subStart=${sub%%/*}
  cd "$subStart"
  sort hosts.txt > hosts.tmp.txt && cp hosts.tmp.txt hosts.txt
 
  router=$(head -1 hosts.tmp.txt | xargs)
  echo "$router"
 
  lines=$(wc -l < hosts.tmp.txt)
  ((lines -= 2))
 
  sed -i "s/$/ unknown WindowsXP/" hosts.txt && \
 
  while read -r ip; do
    crack "$ip"
  done < "hosts.tmp.txt"
 
  xbase=0
  ycur=$ybase
 
  count=0
 
  while read -r ip hostname distro; do
    makeJSON "$ip" "$hostname" "$distro" > "$ip/data.json"
    if [ "$ip" = "$router" ]; then
      echo "                { data: { id: \"$ip\", sub: \"$subStart\", label: \"$ip\n$hostname\", image: \"assets/$distro.png\" }, classes: \"router\", position: { x: 56, y: $((ycur-25)) } }," >> ../../index.html
    else
      echo "                { data: { id: \"$ip\", sub: \"$subStart\", label: \"$ip\n$hostname\", image: \"assets/$distro.png\" }, position: { x: $xbase, y: $ybase } }," >> ../../index.html
      echo "                { data: { id: \"connect_$ip\", source: \"$router\", target: \"$ip\" } }," >> ../../index.html
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
cat index.end.html >> index.html

cp scripts/watcher ../Downloads
cd ../Downloads
./watcher
