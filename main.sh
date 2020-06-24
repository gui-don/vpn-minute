#!/usr/bin/env sh

PROGRAM_NAME="vpn-minute"

export VPNM_PROVIDER=aws
export VPNM_SSH_CONNECTION_ATTEMPTS=30
export VPNM_WG_CLIENT_CONFIG_FILE=$VPNM_HOME/wg0_client.conf

export TF_DATA_DIR=/var/tmp/tobechange

export AWS_DEFAULT_REGION=ca-central-1
export AWS_SECRET_ACCESS_KEY=$AWS_ACCESS_KEY

set -e
#set -x

configure_home() {
  echo -e "Configure home…"

  mkdir -p $VPNM_HOME

  echo -e "-> Home configured."
}

delete_home() {
  echo -e "Delete home…"

  rm -rf $VPNM_HOME

  echo -e "-> Home deleted."
}

check_requirments() {
  if ! [ -x "$(command -v ssh-keygen)" ]; then
    echo "Error: openssh-client is not installed." >&2
    exit 100
  fi

  if ! [ -x "$(command -v scp)" ]; then
    echo "Error: scp is not installed." >&2
    exit 100
  fi

  if ! [ -x "$(command -v terraform)" ]; then
    echo "Error: terraform is not installed." >&2
    exit 101
  fi

  if ! [ -x "$(command -v wg)" ]; then
    echo "Error: wireguard is not installed." >&2
    exit 102
  fi

  if ! [ -x "$(command -v jq)" ]; then
    echo "Error: jq is not installed." >&2
    exit 100
  fi

  if ! [ -x "$(command -v aws)" ]; then
    echo "Error: aws-cli is not installed." >&2
    exit 100
  fi

  if [ -z "$1" ]; then
    echo "No arguments supplied. Valid arguments are: start|stop|status" >&2
    exit 1
  fi

  echo -e "-> Requirements checked."
}

check_arguments() {
  while test $# -gt 0; do
    case "$1" in
    -h | --help)
      echo "$PROGRAM_NAME"
      echo " "
      echo "$PROGRAM_NAME [options] start|stop|status"
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-p, --provider PROVIDER   set the provider to use"
      echo "-r, --region REGION       set the region to use"
      exit 0
      ;;
    -r)
      shift
      if test $# -gt 0; then
        export AWS_DEFAULT_REGION=$1
      else
        echo "No region specified." >&2
        exit 1
      fi
      shift
      ;;
    --region)
      shift
      if test $# -gt 0; then
        export AWS_DEFAULT_REGION=$1
      else
        echo "No region specified." >&2
        exit 1
      fi
      shift
      ;;
    -p)
      shift
      if test $# -gt 0; then
        export VPNM_PROVIDER=$1
      else
        echo "No provider specified." >&2
        exit 1
      fi
      shift
      ;;
    --provider)
      shift
      if test $# -gt 0; then
        export VPNM_PROVIDER=$1
      else
        echo "No provider specified." >&2
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
      echo "Error: $1 is not a valid option" >&2
      exit 1
      ;;
    esac
  done
}

####
# AWS
####

create_ssh_key() {
  echo "Generate temporary ssh key..."

  if [ ! -f /tmp/toberandom ]; then
    ssh-keygen -t rsa -b 4096 -f /tmp/toberandom -C "vpn-minute" -q -N ""
  fi

  export VPNM_SSH_PUBLIC_KEY=$(ssh-keygen -y -f /tmp/toberandom)

  echo -e "-> temporary ssh key generated."
}

delete_ssh_key() {
  echo "Delete temporary ssh key..."

  rm -f /tmp/toberandom /tmp/toberandom.pub

  echo -e "-> temporary ssh key deleted."
}

generate_wireguard_keys() {
  echo "Generate wireguard keys..."

  export WG_SERVER_KEY=$(wg genkey)
  export WG_CLIENT_KEY=$(wg genkey)

  export WG_SERVER_PUBLIC_KEY=$(echo $WG_SERVER_KEY | wg pubkey)
  export WG_CLIENT_PUBLIC_KEY=$(echo $WG_CLIENT_KEY | wg pubkey)

  echo -e "-> wireguard keys generated."
}

run_terraform() {
  echo "Deploy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    terraform init terraform/aws
    terraform apply -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "allow_ssh=true" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
    export WIREGUARD_SERVER_PUBLIC_IP=$(terraform output -json | jq '.public_ip.value' | sed s/\"//g)
    export WIREGUARD_SERVER_INSTANCE_ID=$(terraform output -json | jq '.instance_id.value' | sed s/\"//g)
    generate_wireguard_configuration
    configure_wireguard_server
    terraform apply -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "allow_ssh=false" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
    ;;
  *)
    echo "Error: $VPNM_PROVIDER is not supported yet." >&2
    exit 1
    ;;
  esac

  echo -e "-> infratructure deployed."
}

destroy_terraform() {
  echo "Destroy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    terraform destroy -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=''" -var "allow_ssh=false" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
    ;;
  *)
    echo "Error: $VPNM_PROVIDER is not supported yet." >&2
    exit 1
    ;;
  esac

  rm -rf $TF_DATA_DIR

  echo -e "-> infratructure destroyed."
}

generate_wireguard_configuration() {
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

  umask 066
  echo -e $WIREGUARD_SERVER_CONFIG >/tmp/toberandom-wireguard-server-config
  umask 066
  echo -e $WIREGUARD_CLIENT_CONFIG >/tmp/wg0.conf

  echo -e "-> wireguard configuration generated."
}

delete_wireguard_configuration() {
  echo "Delete wireguard configuration..."

  rm -f /tmp/wg0.conf
  rm -f /tmp/toberandom-wireguard-server-config

  echo -e "-> wireguard configuration deleted."
}

configure_wireguard_server() {
  echo "Configure wireguard server"

  local HOST_KEYS=$(aws --region=$AWS_DEFAULT_REGION ec2 get-console-output --instance-id $WIREGUARD_SERVER_INSTANCE_ID --output text | sed -n '/.*-----BEGIN SSH HOST KEY KEYS-----/,/-----END SSH HOST KEY KEYS-----/p' | sed -n '1!p' | sed -n '$!p' | awk -v ip="$WIREGUARD_SERVER_PUBLIC_IP" '{print ip" "$0}')

  echo $HOST_KEYS >/tmp/vpn-minute-known_host

  scp -i /tmp/toberandom -o UserKnownHostsFile=/tmp/vpn-minute-known_host -o ConnectionAttempts=$VPNM_SSH_CONNECTION_ATTEMPTS /tmp/toberandom-wireguard-server-config ubuntu@$WIREGUARD_SERVER_PUBLIC_IP:~/wg0.conf
  ssh -i /tmp/toberandom -o UserKnownHostsFile=/tmp/vpn-minute-known_host -o ConnectionAttempts=$VPNM_SSH_CONNECTION_ATTEMPTS ubuntu@$WIREGUARD_SERVER_PUBLIC_IP <<'ENDSSH'
set -e 
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y wireguard
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

start_client_wireguard() {
  echo "Start wireguard…"

  if [ ! -f $VPNM_WG_CLIENT_CONFIG_FILE ]; then
    echo "Error: cannot start wireguard client. No such file: $VPNM_WG_CLIENT_CONFIG_FILE." >&2
  fi

  local wg_is_up=$(sudo -E wg show $VPNM_WG_CLIENT_CONFIG_FILE >& /dev/null && echo 1 || echo 0)
  if [ $wg_is_up -eq 0 ]; then
    sudo -E wg-quick up $VPNM_WG_CLIENT_CONFIG_FILE
    echo "-> wireguard started."
  else
    echo "-> wireguard already runnning."
  fi
}

stop_client_wireguard() {
  echo "Stop wireguard…"

  local wg_is_up=$(sudo -E wg show $VPNM_WG_CLIENT_CONFIG_FILE >& /dev/null && echo 1 || echo 0)
  if [ -f $VPNM_WG_CLIENT_CONFIG_FILE -a $wg_is_up -eq 1 ]; then
    sudo -E wg-quick down $VPNM_WG_CLIENT_CONFIG_FILE
    echo "-> wireguard stopped."
  fi

  echo "-> wireguard not runnning."
}

####
# Main
####

main() {
  check_requirments "$@"
  check_arguments "$@"
  configure_home

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
    delete_home
    ;;
  status)
    echo "Not implemented yet."
    ;;
  *)
    echo "Error: $ACTION is not a valid." >&2
    exit 1
    ;;
  esac
}

main "$@"
