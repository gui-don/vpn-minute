#!/usr/bin/env sh

PROGRAM_NAME="vpn-minute"

export PROVIDER=aws
export REGION=ca-central-1
export TF_DATA_DIR=/var/tmp/tobechange
export SSH_TIMEOUT=30

set -e
#set -x

check_requirments()
{
    if ! [ -x "$(command -v ssh-keygen)" ]; then
		echo "Error: openssh-client is not installed." >&2
		exit 100
	fi
     
    if ! [ -x "$(command -v sftp)" ]; then
		echo "Error: sftp is not installed." >&2
		exit 100
	fi

    if ! [ -x "$(command -v terraform)" ]; then
		echo "Error: terraform is not installed." >&2
		exit 101
	fi
    
    if ! [ -x "$(command -v wg)" ]; then
		echo "Error: wireguard-tools is not installed." >&2
		exit 102
	fi
    
    if ! [ -x "$(command -v jq)" ]; then
		echo "Error: jq is not installed." >&2
		exit 100
	fi

	if [ -z "$1" ]; then
		echo "No arguments supplied. Valid arguments are: start|stop|status" >&2
		exit 1
	fi    

	echo -e "-> Requirements checked."
}

check_arguments()
{
  while test $# -gt 0; do
    case "$1" in
      -h|--help)
        echo "$PROGRAM_NAME"
        echo " "
        echo "$PROGRAM_NAME [options] start|stop|status"
        echo " "
        echo "options:"
        echo "-h, --help                show brief help"
        echo "-p, --provider PROVIDER   set the region to use"
        echo "-r, --region REGION       set the region to use"
        exit 0
      ;;
      -r)
        shift
        if test $# -gt 0; then
          export REGION=$1
        else
          echo "no region specified"
          exit 1
        fi
        shift
      ;;
      --region)
        shift
        if test $# -gt 0; then
          export REGION=$1
        else
          echo "no region specified"
          exit 1
        fi
        shift
      ;;
      -p)
        shift
        if test $# -gt 0; then
          export PROVIDER=$1
        else
          echo "no provider specified"
          exit 1
        fi
        shift
      ;;
      --provider)
        shift
        if test $# -gt 0; then
          export PROVIDER=$1
        else
          echo "no provider specified"
          exit 1
        fi
        shift
      ;;
      start)
        ACTION=start
        break
      ;;
      stop)
        ACTION=stop
        break
      ;;
      status)
        ACTION=status
        break
      ;;
      *)
        echo "Error: $1 is not a valid option"
        exit 1
      ;;
    esac
  done
}

####
# AWS
####

create_ssh_key()
{
  echo "Generate temporary ssh key..."
 
  if [ ! -f /tmp/toberandom ]; then
    ssh-keygen -t rsa -b 4096 -f /tmp/toberandom -C "vpn-minute" -q -N ""
  fi

  export SSH_PUBLIC_KEY=$(ssh-keygen -y -f /tmp/toberandom)

  echo -e "-> temporary ssh key generated."
}

delete_ssh_key()
{
  echo "Delete temporary ssh key..."

  rm -f /tmp/toberandom /tmp/toberandom.pub 

  echo -e "-> temporary ssh key deleted." 
}

generate_wireguard_keys()
{
  echo "Generate wireguard keys..."

  export WG_SERVER_KEY=$(wg genkey)
  export WG_CLIENT_KEY=$(wg genkey)

  export WG_SERVER_PUBLIC_KEY=$(echo $WG_SERVER_KEY |wg pubkey)
  export WG_CLIENT_PUBLIC_KEY=$(echo $WG_CLIENT_KEY |wg pubkey)

  echo -e "-> wireguard keys generated."
}

run_terraform() {
  echo "Deploy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $PROVIDER in
    aws)
      terraform init terraform/aws
      terraform apply -auto-approve -var "region=$REGION" -var "public_key=$SSH_PUBLIC_KEY" -var "allow_ssh=true" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_KEY" terraform/aws
      export WIREGUARD_SERVER_PUBLIC_IP=$(terraform output -json |jq '.public_ip.value'|sed s/\"//g)
      generate_wireguard_configuration
      configure_serveur_wireguard
      terraform apply -auto-approve -var "region=$REGION" -var "public_key=$SSH_PUBLIC_KEY" -var "allow_ssh=false" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_KEY" terraform/aws
    ;;
    *)
      echo "Error: $PROVIDER is not supported yet."
      exit 1
    ;;
  esac

  echo -e "-> infratructure deployed."
}

destroy_terraform() {
  echo "Destroy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $PROVIDER in
    aws)
      terraform destroy -auto-approve -var "region=$REGION" -var "public_key=''" -var "allow_ssh=false" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_KEY" terraform/aws
    ;;
    *)
      echo "Error: $PROVIDER is not supported yet."
      exit 1
    ;;
  esac

  rm -rf $TF_DATA_DIR

  echo -e "-> infratructure destroyed."
}

generate_wireguard_configuration()
{
  echo "Generate wigreguard configuration..."

WIREGUARD_SERVER_CONFIG="[Interface]\\n\
Address = 192.168.2.1 \\n\
PrivateKey = $WG_SERVER_KEY\\n\
ListenPort = 51820\\n\
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE\\n\
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE\\n\
[Peer]\\n\
PublicKey = $WG_CLIENT_PUBLIC_KEY\\n\
AllowedIPs = 192.168.2.2/32"

WIREGUARD_CLIENT_CONFIG="[Interface]\\n\
Address = 192.168.2.2\\n\
PrivateKey = $WG_CLIENT_KEY\\n\
\\n\
[Peer]\\n\
PublicKey = "$WG_SERVER_PUBLIC_KEY"\\n\
AllowedIPs = 0.0.0.0/0\\n\
Endpoint = $WIREGUARD_SERVER_PUBLIC_IP:51820"

  umask 066; echo -e $WIREGUARD_SERVER_CONFIG > /tmp/toberandom-wireguard-server-config
  umask 066; echo -e $WIREGUARD_CLIENT_CONFIG > /tmp/wg0.conf

  echo -e "-> wireguard configuration generated."
}

delete_wireguard_configuration() {
  echo "Delete wigreguard configuration..."

  rm -f /tmp/wg0.conf
  rm -f /tmp/toberandom-wireguard-server-config

  echo -e "-> wireguard configuration deleted."
}

configure_serveur_wireguard() {
  echo "Configure wireguard server"

  sleep 15

  sftp -i /tmp/toberandom -o StrictHostKeyChecking=no -o ConnectionAttempts=$SSH_TIMEOUT /tmp/toberandom-wireguard-server-config ubuntu@$WIREGUARD_SERVER_PUBLIC_IP:~/wg0.conf
  ssh -i /tmp/toberandom -o StrictHostKeyChecking=no -o ConnectionAttempts=$SSH_TIMEOUT ubuntu@$WIREGUARD_SERVER_PUBLIC_IP <<'ENDSSH'
set -e 
sudo add-apt-repository -y ppa:wireguard/wireguard
sudo apt-get update
sudo apt-get install -y wireguard-dkms wireguard-tools
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p
sudo mv ~/wg0.conf /etc/wireguard/
sudo chown -R root:root /etc/wireguard
sudo chmod -R og-rwx /etc/wireguard/
sudo systemctl start wg-quick@wg0.service
ENDSSH
  
  rm -f /tmp/toberandom-wireguard-server-config

  echo "-> wireguard server configured."
}

start_client_wireguard()
{
  sudo wg-quick up /tmp/wg0.conf
}

stop_client_wireguard()
{
  sudo wg-quick down /tmp/wg0.conf
}

####
# Main
####

main()
{
  check_requirments "$@"
  check_arguments "$@"
  
  case $ACTION in
    start)
      create_ssh_key
      generate_wireguard_keys
      run_terraform
      start_client_wireguard
    ;;
    stop)
      stop_client_wireguard
      destroy_terraform
      delete_wireguard_configuration
      delete_ssh_key
    ;;
    status)
      echo "Not implemented yet."
    ;;
    *)
      echo "Error: $ACTION is not a valide "
      exit 1
    ;;
  esac
}

main "$@"
