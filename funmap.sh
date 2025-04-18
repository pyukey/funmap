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
 
findFamily() {
  case "$1" in
    Debian) echo "Linux";;
    Ubuntu) echo "Linux";;
    Kali) echo "Linux";;
    RHEL) echo "Linux";;
    CentOS) echo "Linux";;
    Fedora) echo "Linux";;
    Rocky) echo "Linux";;
    Alma) echo "Linux";;
    Arch) echo "Linux";;
    Manjaro) echo "Linux";;
    Endeavour) echo "Linux";;
    Alpine) echo "Linux";;
    NixOS) echo "Linux";;
    FreeBSD) echo "BSD";;
    OpenBSD) echo "BSD";;
    NetBSD) echo "BSD";;
    DragonFly) echo "BSD";;
    *) echo "Windows";;
  esac
}

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
          distro="Unknown"
        fi
	echo "$user $pass" > "$ip/pass.txt"
        echo "$ip:$user:$pass" >> crack.txt
        sed -i "/$ip/s/ unknown Unknown/ $name $distro/" hosts.txt
        return
      fi
    done < "$path/pass.txt"
  done < "$path/users.txt"
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

rollPasswd() {
  if grep -q "$1:" crack.txt; then
    user="$(grep "$1:" crack.txt | awk -F: '{print $2}')"
    pass="$(grep "$1:" crack.txt | awk -F: '{print $3}')"
    sshpass -p $pass scp "$path/plus" $user@$1:
    sshpass -p $pass scp "$path/$2/agent" $user@$1:
    sshpass -p $pass ssh -tt $user@$1 "echo '$pass' | sudo -S bash ./assets/rollPasswd.sh" > "$ip/pass.txt"
  fi
}

printf "\033[01m\033[04mUSERS\033[00m\n"
read -p "Enter default user: " user
while true; do
  if [ "$user" = "done" ]; then
    break
  else
    echo "$user" >> "$path/users.txt"
  fi
  read -p "Enter default user. [Type done to stop]: " user
done
 
printf "\033[01m\033[04mPASSWDS\033[00m\n"
read -p "Enter default password: " pass
while true; do
  if [ "$pass" = "done" ]; then
    break
  else
    echo "$pass" >> "$path/pass.txt"
  fi
  read -p "Enter default password. [Type done to stop]: " pass
done
 
printf "\033[01m\033[04mSUBNETS\033[00m\n"
regex='^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$'
read -p "Enter a subnet to scan: " sub
while [[ $sub =~ $regex ]]; do
  echo "$sub" >> subnets
  read -p "Enter a subnet to scan. [Type done to stop]: " sub
done
while read -r sub; do
  subStart=${sub%%/*}
  mkdir "$subStart"
  cd "$subStart"
  nmap -PR -PE -PP -PM -PO2 -PS21,22,23,25,80,110,113,135,137,143,443,445,691,993,995,1433,1521,2483,2484,3306,8008,8080,8443,7680,31339 -PA80,113,443,10042 -sn "$sub" | grep report | awk '{print $5" "$6}' > hosts.txt
  sed -i -E 's/^(\S+)\s+.(.*).$/\2 /' hosts.txt
  while read -r host; do
    ip=$(echo "$host" | awk '{print $1}')
    mkdir "$ip"
    nmap -sS -sV "$ip" > "$ip/nmap.txt" 2>/dev/null &
  done < hosts.txt
  cd ..
done < subnets
 
echo "Start scanning!"
 
cat ../index.template.html > ../index.html
ybase=25
while read -r sub; do
  subStart=${sub%%/*}
  cd "$subStart"
  sort hosts.txt > hosts.tmp.txt && cp hosts.tmp.txt hosts.txt
 
  router=$(head -1 hosts.tmp.txt | xargs)
 
  lines=$(wc -l < hosts.tmp.txt)
  ((lines -= 2))
 
  sed -i "s/$/ unknown Unknown/" hosts.txt && \
 
  while read -r ip; do
    crack "$ip"
  done < "hosts.tmp.txt"
 
  xbase=0
  ycur=$ybase
 
  count=0
 
  while read -r ip hostname distro; do
    fam="$(findFamily $distro)"
    rollPasswd "$ip" "$fam" &
    makeJSON "$ip" "$hostname" "$distro" > "$ip/data.json"
    if [ "$ip" = "$router" ]; then
      echo "                { data: { id: \"$ip\", sub: \"$subStart\", label: \"$ip\n$hostname\", hostname: \"$hostname\", distro: \"$distro\", image: \"assets/$distro.png\" }, classes: \"router\", position: { x: 56, y: $((ycur-25)) } }," >> ../../index.html
    else
      echo "                { data: { id: \"$ip\", sub: \"$subStart\", label: \"$ip\n$hostname\", hostname: \"$hostname\", distro: \"$distro\", image: \"assets/$distro.png\" }, position: { x: $xbase, y: $ybase } }," >> ../../index.html
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
