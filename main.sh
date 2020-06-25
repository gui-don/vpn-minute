#!/usr/bin/env bash

export VPNM_VERBOSE=false
export VPNM_PROVIDER="aws"
export VPNM_HOME="/tmp/vpnm"
export VPNM_ALLOW_SSH=false
export VPNM_SSH_USER="ubuntu"
export VPNM_SSH_KEY_FILE="$VPNM_HOME/id_rsa"
export VPNM_SSH_KNOWN_HOST_FILE="$VPNM_HOME/known_hosts"
export VPNM_WG_CLIENT_CONNECTION_NAME="wg0_client"
export VPNM_WG_SERVER_CONFIG_FILE="$VPNM_HOME/wg0_server.conf"
export VPNM_WG_CLIENT_CONFIG_FILE="$VPNM_HOME/$VPNM_WG_CLIENT_CONNECTION_NAME.conf"
export VPNM_APPLICATION_NAME="vpn-minute"

export TF_DATA_DIR="$VPNM_HOME/terraform"
export TF_IN_AUTOMATION=true
export TF_STATE_FILE="$VPNM_HOME/terraform_state/terraform.tfstate"

export AWS_DEFAULT_REGION="ca-central-1"
if ! [ -z "$AWS_ACCESS_KEY_ID" ]; then
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
fi
if ! [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
fi

set -e

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

check_requirements() {
  echo -e "Check requirements…"

  if [ "$VPNM_ALLOW_SSH" = true ] && ! [ -x "$(command -v ssh)" ]; then
    print_error "\e[1mssh\e[22m command is not available in your system."
    exit 101
  fi

  if [ "$VPNM_ALLOW_SSH" = true ] && ! [ -x "$(command -v ssh-keygen)" ]; then
    print_error "\e[1mssh-keygen\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v base64)" ]; then
    print_error "\e[1mbase64\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v terraform)" ]; then
    print_error "\e[1mterraform\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v wg)" ]; then
    print_error "\e[1mwg\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v jq)" ]; then
    print_error "\e[1mjq\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v aws)" ]; then
    print_error "\e[1maws\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v sudo)" ]; then
    print_error "\e[1msudo\e[22m command is not available in your system."
    exit 101
  fi

  if [ -z "$1" ]; then
    print_warn "No arguments supplied. Valid arguments are: start|stop|status"
    exit 1
  fi

  echo -e "-> Requirements checked."
}

print_error() {
  echo -e "\e[91mError: $1\e[39m" >&2
}

print_warn() {
  echo -e "\e[93m$1\e[0m" >&2
}

display_help() {
  echo "$VPNM_APPLICATION_NAME"
  echo " "
  echo "$VPNM_APPLICATION_NAME [options] start|stop|status"
  echo " "
  echo "options:"
  echo "-v                        verbose mode"
  echo "-vvv                      debug mode"
  echo "-h, --help                show brief help"
  echo "-p, --provider PROVIDER   set the provider to use"
  echo "-r, --region REGION       set the region to use, see below"
  echo "--ssh                     allows SSH connection to the $VPNM_APPLICATION_NAME server"
  echo " "
  echo "== Provider $VPNM_PROVIDER =="
  echo "Available regions:        "$(get_available_regions)
  echo " "
  exit 0
}

check_arguments() {
  while test $# -gt 0; do
    case "$1" in
    -h | --help)
      display_help
      ;;
    -v)
      VPNM_VERBOSE=true
      shift
      ;;
    -vv | -vvv)
      set -x
      shift
      ;;
    --ssh)
      export VPNM_ALLOW_SSH=true
      shift
      ;;
    -r | --region)
      shift
      if test $# -gt 0; then
        export AWS_DEFAULT_REGION=$1
      else
        print_warn "No region specified."
        exit 1
      fi
      shift
      ;;
    -p | --provider)
      shift
      if test $# -gt 0; then
        export VPNM_PROVIDER=$1
      else
        print_warn "No provider specified."
        exit 1
      fi
      shift
      ;;
    start)
      VPNM_ACTION=start
      shift
      ;;
    stop)
      VPNM_ACTION=stop
      shift
      ;;
    status)
      VPNM_ACTION=status
      shift
      ;;
    *)
      print_error "\e[1m$1\e[22m is not a valid option."
      exit 1
      ;;
    esac
  done
}

####
# SSH
####

display_ssh_command() {
  echo -e "To connect to the $VPNM_APPLICATION_NAME server with SSH, use:"

  echo -e "  $ ssh -i $VPNM_SSH_KEY_FILE -o UserKnownHostsFile=$VPNM_SSH_KNOWN_HOST_FILE $VPNM_SSH_USER@$VPNM_WG_SERVER_PUBLIC_IP"
}

create_ssh_key() {
  echo "Generate SSH key..."

  if [ ! -f $VPNM_SSH_KEY_FILE ]; then
    ssh-keygen -t rsa -b 4096 -f $VPNM_SSH_KEY_FILE -C "$VPNM_APPLICATION_NAME" -q -N ""

    echo -e "-> SSH key generated."
  else
    echo -e "-> SSH key already generated."
  fi

  export VPNM_SSH_PUBLIC_KEY=$(ssh-keygen -y -f $VPNM_SSH_KEY_FILE)
}

delete_ssh_key() {
  echo "Delete SSH key..."

  rm -f $VPNM_SSH_KEY_FILE $VPNM_SSH_KEY_FILE.pub

  echo -e "-> SSH key deleted."
}

####
# VPN
####

generate_wireguard_keys() {
  echo "Generate wireguard keys..."

  if [ ! -f "$VPNM_WG_SERVER_CONFIG_FILE" ]; then
    export VPNM_WG_SERVER_KEY=$(wg genkey)
    export VPNM_WG_SERVER_PUBLIC_KEY=$(echo "$VPNM_WG_SERVER_KEY" | wg pubkey)
    echo -e "-> wireguard server keys generated."
  else
    echo -e "-> wireguard server keys already generated."
  fi

  if [ ! -f "$VPNM_WG_CLIENT_CONFIG_FILE" ]; then
    export VPNM_WG_CLIENT_KEY=$(wg genkey)
    export VPNM_WG_CLIENT_PUBLIC_KEY=$(echo "$VPNM_WG_CLIENT_KEY" | wg pubkey)
    echo -e "-> wireguard client keys generated."
  else
    echo -e "-> wireguard client keys already generated."
  fi
}

generate_wireguard_client_configuration() {
  echo "Generate wireguard client configuration..."

  if [ ! -f "$VPNM_WG_CLIENT_CONFIG_FILE" ]; then
    VPNM_WG_CLIENT_CONFIG="[Interface]\\n\
Address = 192.168.2.2\\n\
PrivateKey = $VPNM_WG_CLIENT_KEY\\n\
\\n\
[Peer]\\n\
PublicKey = "$VPNM_WG_SERVER_PUBLIC_KEY"\\n\
AllowedIPs = 0.0.0.0/0\\n\
Endpoint = $VPNM_WG_SERVER_PUBLIC_IP:51820"
    umask 066
    echo -e "$VPNM_WG_CLIENT_CONFIG" >$VPNM_WG_CLIENT_CONFIG_FILE
    echo -e "-> wireguard client configuration generated."
  else
    echo -e "-> wireguard client configuration already generated."
  fi
}

generate_wireguard_server_configuration() {
  echo "Generate wireguard client configuration..."

  if [ ! -f "$VPNM_WG_SERVER_CONFIG_FILE" ]; then
    VPNM_WG_SERVER_CONFIG="[Interface]\\n\
Address = 192.168.2.1 \\n\
PrivateKey = $VPNM_WG_SERVER_KEY\\n\
ListenPort = 51820\\n\
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE\\n\
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE\\n\
[Peer]\\n\
PublicKey = $VPNM_WG_CLIENT_PUBLIC_KEY\\n\
AllowedIPs = 192.168.2.2/32"
    umask 066
    echo -e "$VPNM_WG_SERVER_CONFIG" >$VPNM_WG_SERVER_CONFIG_FILE
    echo -e "-> wireguard server configuration generated."
  else
    echo -e "-> wireguard server configuration already generated."
  fi
}

delete_wireguard_configurations() {
  echo "Delete wireguard configuration..."

  rm -f $VPNM_WG_CLIENT_CONFIG_FILE
  rm -f $VPNM_WG_SERVER_CONFIG_FILE

  echo -e "-> wireguard configuration deleted."
}

start_client_wireguard() {
  echo "Start wireguard…"

  if [ ! -f $VPNM_WG_CLIENT_CONFIG_FILE ]; then
    print_error "Error: cannot start wireguard client. No such file: \e[1m$VPNM_WG_CLIENT_CONFIG_FILE\e[22m."
  fi

  local wg_is_up=$(sudo -E wg show $VPNM_WG_CLIENT_CONNECTION_NAME >&/dev/null && echo 1 || echo 0)
  if [ $wg_is_up -eq 0 ]; then
    sudo -E wg-quick up $VPNM_WG_CLIENT_CONFIG_FILE
    echo "-> wireguard started."
  else
    echo "-> wireguard already runnning."
  fi
}

stop_client_wireguard() {
  echo "Stop wireguard…"

  local wg_is_up=$(sudo -E wg show $VPNM_WG_CLIENT_CONNECTION_NAME >&/dev/null && echo 1 || echo 0)
  if [ $wg_is_up -eq 1 ]; then
    if [ ! -f $VPNM_WG_CLIENT_CONFIG_FILE ]; then
      umask 066
      sudo wg showconf wg0_client > $VPNM_WG_CLIENT_CONFIG_FILE
    fi

    sudo -E wg-quick down $VPNM_WG_CLIENT_CONFIG_FILE
    echo "-> wireguard stopped."
  else
    echo "-> wireguard not runnning."
  fi
}

####
# Infrastructure
####

get_available_regions() {
  case $VPNM_PROVIDER in
  aws)
    echo "af-south-1, eu-north-1, ap-south-1, eu-west-3, eu-west-2, eu-west-1, eu-central-1, eu-south-1, ap-northeast-2, me-south-1, ap-northeast-1, sa-east-1, ca-central-1, ap-east-1, ap-southeast-1, ap-southeast-2, us-east-1, us-east-2, us-west-1, us-west-2"
    ;;
  *)
    echo print_error "\e[1m$VPNM_PROVIDER\e[22m is not supported yet. Pull requests are welcomed."
    exit 1
    ;;
  esac
}

deploy_infrastructure() {
  echo "Deploy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    HOME=$VPNM_HOME terraform init terraform/aws
    HOME=$VPNM_HOME terraform apply -state=$TF_STATE_FILE -state-out=$TF_STATE_FILE -auto-approve -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "base64_vpn_server_config=$(base64 $VPNM_WG_SERVER_CONFIG_FILE)" -var "application_name=$VPNM_APPLICATION_NAME" -var "allow_ssh=$VPNM_ALLOW_SSH" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws

    echo "Waiting for SSH..."

    if [ "$VPNM_ALLOW_SSH" = true ]; then
      while [ "$(HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq '.ssh_known_hosts.value' | sed s/\"//g)" == "IN PROGRESS..." ]; do
        HOME=$VPNM_HOME terraform refresh -state=$TF_STATE_FILE -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "base64_vpn_server_config=$(base64 $VPNM_WG_SERVER_CONFIG_FILE)" -var "application_name=$VPNM_APPLICATION_NAME" -var "allow_ssh=$VPNM_ALLOW_SSH" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
        sleep 5
      done
    fi

    echo -e "-> SSH ready."

    export VPNM_WG_SERVER_PUBLIC_IP=$(HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq '.public_ip.value' | sed s/\"//g)
    export VPNM_WG_SERVER_INSTANCE_ID=$(HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq '.instance_id.value' | sed s/\"//g)

    if [ "$VPNM_ALLOW_SSH" = true ]; then
      HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq -r '.ssh_known_hosts.value' | sed s/\"//g | base64 -d >$VPNM_SSH_KNOWN_HOST_FILE
    fi
    ;;
  *)
    echo print_error "\e[1m$VPNM_PROVIDER\e[22m is not supported yet. Pull requests are welcomed."
    exit 1
    ;;
  esac

  echo -e "-> infrastructure deployed."
}

destroy_infrastructure() {
  echo "Destroy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    local already_used_region="$(HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq '.region.value' | sed s/\"//g)"

    if [ -f "$TF_STATE_FILE" ]; then
      HOME=$VPNM_HOME terraform destroy -state=$TF_STATE_FILE -state-out=$TF_STATE_FILE -auto-approve -var "region=${already_used_region:-$AWS_DEFAULT_REGION}" -var "public_key=''" -var "base64_vpn_server_config=" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" terraform/aws
    fi
    ;;
  *)
    print_error "\e[1m$VPNM_PROVIDER\e[22m is not supported yet. Pull requests are welcomed."
    exit 1
    ;;
  esac

  rm -rf $TF_DATA_DIR

  echo -e "-> infrastructure destroyed."
}

check_status() {
  echo "Check wireguard server status"

  if [ "$VPNM_ALLOW_SSH" = true ]; then
    ssh -i $VPNM_SSH_KEY_FILE -o UserKnownHostsFile=$VPNM_SSH_KNOWN_HOST_FILE -o ConnectionAttempts=30 $VPNM_SSH_USER@$VPNM_WG_SERVER_PUBLIC_IP <<'ENDSSH'
      echo test
ENDSSH
  fi

  echo "-> wireguard server status checked."
}

####
# Main
####

main() {
  check_arguments "$@"

  case $VPNM_ACTION in
  start)
    check_requirements "$@"
    configure_home
    generate_wireguard_keys
    generate_wireguard_server_configuration
    if [ "$VPNM_ALLOW_SSH" = true ]; then
      create_ssh_key
    fi
    deploy_infrastructure
    generate_wireguard_client_configuration
    start_client_wireguard
    check_status
    if [ "$VPNM_ALLOW_SSH" = true ]; then
      display_ssh_command
    fi
    exit 0
    ;;
  stop)
    check_requirements "$@"
    configure_home
    stop_client_wireguard
    destroy_infrastructure
    delete_wireguard_configurations
    if [ "$VPNM_ALLOW_SSH" = true ]; then
      delete_ssh_key
    fi
    delete_home
    exit 0
    ;;
  status)
    echo -e "\e[1mstatus\e[22m is not implemented yet."
    ;;
  "")
    display_help
    exit 0
    ;;
  *)
    print_error "\e[1m$VPNM_ACTION\e[22m is not a valid action."
    exit 1
    ;;
  esac
}

main "$@"
