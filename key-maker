#!/bin/bash

# Simple tool for generating an ssh key and putting
# it on another system. I always forget these steps
# so I'm actually putting them in a script so I won't
# have to keep looking this crap up.


KEY_NAME="id_rsa"

# This function take from ghoti's answer on stack overflow
# because I'm lazy and didn't feel like figuring this out
# myself. He rocks.
ipvalid() {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)

  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1

  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done

  return 0
}


echo ""
echo "========================================="
echo "          SSH KEY GEN TOOL"
echo "========================================="
echo ""

# Generate the id_rsa* files
if [ -f ~/.ssh/id_rsa ]; then
	echo "Prexisting ssh key found. You can use this one or generate a new one."

	while true; do
		read -r -p "Use existing key? [y/n] " -n 1 input
		echo ""

		case $input in
			[yY])
				echo "Using preexisting key"
				KEY_NAME="id_rsa"
				break
				;;
			[nN])
				echo "Generating New Key"
				ssh-keygen -t rsa -f ~/.ssh/$KEY_NAME -N ""
				break
				;;
			*)
				echo "Invalid input" ;;
		esac
	done
	
else
	echo "No key found, generating new key"

	if [ -d ~/.ssh ] ; then
		mkdir -p ~/.ssh
	fi
		
	ssh-keygen -t rsa -f ~/.ssh/$KEY_NAME -N ""
fi

echo ""

# Let's get the IP of the box we want to ssh into
while true; do
	read -r -p "Enter the IP of the system you want to ssh into: " ip

	if ipvalid "$ip"; then
		break
	else
		echo 'Invalid IP'
	fi
done

# Get the user name
echo ""
read -r -p "Enter the name of the user on the remote system: " user_name

echo ""
ssh $user_name@$ip mkdir -p .ssh
cat ~/.ssh/"$KEY_NAME".pub | ssh "$user_name@$ip" 'cat >> .ssh/authorized_keys'

ssh $user_name@$ip "chmod 700 .ssh; chmod 640 .ssh/authorized_keys"
