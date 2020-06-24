#!/usr/bin/env bash

export VPNM_PROVIDER=aws
export VPNM_HOME=/tmp/vpnm
export VPNM_SSH_CONNECTION_ATTEMPTS=30
export VPNM_SSH_KEY_FILE=$VPNM_HOME/id_rsa
export VPNM_SSH_KNOWN_HOST_FILE=$VPNM_HOME/known_host
export VPNM_WG_SERVER_CONFIG_FILE=$VPNM_HOME/wg0_server.conf
export VPNM_WG_CLIENT_CONFIG_FILE=$VPNM_HOME/wg0_client.conf
export VPNM_APPLICATION_NAME="vpn-minute"

export TF_DATA_DIR=$VPNM_HOME

export AWS_DEFAULT_REGION=ca-central-1
if ! [ -z "$AWS_ACCESS_KEY_ID" ]; then
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
fi
if ! [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
fi


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
  echo -e "Check requirments…"

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
    exit 103
  fi

  if ! [ -x "$(command -v aws)" ]; then
    echo "Error: aws-cli is not installed." >&2
    exit 104
  fi

  if ! [ -x "$(command -v ssh-keygen)" ]; then
    echo "Error: openssh-client is not installed." >&2
    exit 105
  fi

  if ! [ -x "$(command -v sudo)" ]; then
    echo "Error: is not installed." >&2
    exit 106
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
      echo "$VPNM_APPLICATION_NAME"
      echo " "
      echo "$VPNM_APPLICATION_NAME [options] start|stop|status"
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
  echo "Generate temporary SSH key..."

  if [ ! -f $VPNM_SSH_KEY_FILE ]; then
    ssh-keygen -t rsa -b 4096 -f $VPNM_SSH_KEY_FILE -C "vpn-minute" -q -N ""
  fi

  export VPNM_SSH_PUBLIC_KEY=$(ssh-keygen -y -f $VPNM_SSH_KEY_FILE)

  echo -e "-> temporary SSH key generated."
}

delete_ssh_key() {
  echo "Delete temporary ssh key..."

  rm -f $VPNM_SSH_KEY_FILE $VPNM_SSH_KEY_FILE.pub

  echo -e "-> temporary ssh key deleted."
}

generate_wireguard_keys() {
  echo "Generate wireguard keys..."

  export VPNM_WG_SERVER_KEY=$(wg genkey)
  export VPNM_WG_CLIENT_KEY=$(wg genkey)

  export VPNM_WG_SERVER_PUBLIC_KEY=$(echo $VPNM_WG_SERVER_KEY | wg pubkey)
  export VPNM_WG_CLIENT_PUBLIC_KEY=$(echo $VPNM_WG_CLIENT_KEY | wg pubkey)

  echo -e "-> wireguard keys generated."
}

run_terraform() {
  echo "Deploy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    HOME=$VPNM_HOME terraform init terraform/aws
    HOME=$VPNM_HOME terraform apply -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "application_name=$VPNM_APPLICATION_NAME" -var "allow_ssh=true" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
    export VPNM_WG_SERVER_PUBLIC_IP=$(HOME=$VPNM_HOME terraform output -json | jq '.public_ip.value' | sed s/\"//g)
    export VPNM_WG_SERVER_INSTANCE_ID=$(HOME=$VPNM_HOME terraform output -json | jq '.instance_id.value' | sed s/\"//g)
    generate_wireguard_configuration
    configure_wireguard_server
    HOME=$VPNM_HOME terraform apply -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "application_name=$VPNM_APPLICATION_NAME" -var "allow_ssh=false" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
    ;;
  *)
    echo "Error: $VPNM_PROVIDER is not supported yet." >&2
    exit 1
    ;;
  esac

  echo -e "-> infrastructure deployed."
}

destroy_terraform() {
  echo "Destroy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    HOME=$VPNM_HOME terraform destroy -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=''" -var "allow_ssh=false" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
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

  VPNM_WG_SERVER_CONFIG="[Interface]\\n\
Address = 192.168.2.1 \\n\
PrivateKey = $VPNM_WG_SERVER_KEY\\n\
ListenPort = 51820\\n\
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE\\n\
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE\\n\
[Peer]\\n\
PublicKey = $VPNM_WG_CLIENT_PUBLIC_KEY\\n\
AllowedIPs = 192.168.2.2/32"

  VPNM_WG_CLIENT_CONFIG="[Interface]\\n\
Address = 192.168.2.2\\n\
PrivateKey = $VPNM_WG_CLIENT_KEY\\n\
\\n\
[Peer]\\n\
PublicKey = "$VPNM_WG_SERVER_PUBLIC_KEY"\\n\
AllowedIPs = 0.0.0.0/0\\n\
Endpoint = $VPNM_WG_SERVER_PUBLIC_IP:51820"

  umask 066
  echo -e $VPNM_WG_SERVER_CONFIG > $VPNM_WG_SERVER_CONFIG_FILE
  umask 066
  echo -e $VPNM_WG_CLIENT_CONFIG > $VPNM_WG_CLIENT_CONFIG_FILE

  echo -e "-> wireguard configuration generated."
}

delete_wireguard_configuration() {
  echo "Delete wireguard configuration..."

  rm -f $VPNM_WG_CLIENT_CONFIG_FILE
  rm -f $VPNM_WG_SERVER_CONFIG_FILE

  echo -e "-> wireguard configuration deleted."
}

configure_wireguard_server() {
  echo "Configure wireguard server"

  local HOST_KEYS=$(aws --region=$AWS_DEFAULT_REGION ec2 get-console-output --instance-id $VPNM_WG_SERVER_INSTANCE_ID --output text | sed -n '/.*-----BEGIN SSH HOST KEY KEYS-----/,/-----END SSH HOST KEY KEYS-----/p' | sed -n '1!p' | sed -n '$!p' | awk -v ip="$VPNM_WG_SERVER_PUBLIC_IP" '{print ip" "$0}')

  sh -c "echo $HOST_KEYS > $VPNM_SSH_KNOWN_HOST_FILE"

  scp -i $VPNM_SSH_KEY_FILE -o UserKnownHostsFile=$VPNM_SSH_KNOWN_HOST_FILE -o ConnectionAttempts=$VPNM_SSH_CONNECTION_ATTEMPTS $VPNM_WG_SERVER_CONFIG_FILE ubuntu@$VPNM_WG_SERVER_PUBLIC_IP:~/wg0.conf
  ssh -i $VPNM_SSH_KEY_FILE -o UserKnownHostsFile=$VPNM_SSH_KNOWN_HOST_FILE -o ConnectionAttempts=$VPNM_SSH_CONNECTION_ATTEMPTS ubuntu@$VPNM_WG_SERVER_PUBLIC_IP <<'ENDSSH'
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

  rm -f $VPNM_WG_SERVER_CONFIG_FILE

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
