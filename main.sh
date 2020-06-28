#!/usr/bin/env bash

export VPNM_APPLICATION_NAME="vpn-minute"
export VPNM_VERBOSE=false
export VPNM_HOME="${XDG_DATA_HOME:-~/.local/share}/vpnm"
export VPNM_CODE_TERRAFORM_PATH="/usr/share/$VPNM_APPLICATION_NAME/terraform"
if [ ! -f "$VPNM_CODE_TERRAFORM_PATH" ]; then
  export VPNM_CODE_TERRAFORM_PATH="terraform"
fi

export VPNM_PROVIDER="aws"

export VPNM_WG_SERVER_CONFIG_NAME="wg0_server"
export VPNM_WG_CLIENT_CONFIG_NAME="wg0_client"
export VPNM_WG_TEST_CONFIG_NAME="wg0_test"
export VPNM_WG_SERVER_CONFIG_FILE="$VPNM_HOME/$VPNM_WG_SERVER_CONFIG_NAME.conf"
export VPNM_WG_CLIENT_CONFIG_FILE="$VPNM_HOME/$VPNM_WG_CLIENT_CONFIG_NAME.conf"
export VPNM_WG_TEST_CONFIG_FILE="$VPNM_HOME/$VPNM_WG_TEST_CONFIG_NAME.conf"

export VPNM_OS="ubuntu"
export VPNM_OS_POSTROUTING_INTERFACE="ens5"

export VPNM_ALLOW_SSH=false
export VPNM_SSH_USER="$VPNM_OS"
export VPNM_SSH_KEY_FILE="$VPNM_HOME/id_rsa"
export VPNM_SSH_KNOWN_HOST_FILE="$VPNM_HOME/known_hosts"

####
# Terraform-specific variables
####

export TF_DATA_DIR="$VPNM_HOME/terraform"
export TF_IN_AUTOMATION=true
export TF_STATE_FILE="$VPNM_HOME/terraform_state/terraform.tfstate"

####
# AWS-specific variables
####

export AWS_DEFAULT_REGION="ca-central-1"
if ! [ -z "$AWS_ACCESS_KEY_ID" ]; then
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
fi
if ! [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
fi

set -e

####
# Command line utilities
####

configure_home() {
  print_message "Configure home…"

  mkdir -p $VPNM_HOME

  print_message "✔ Home configured."
}

delete_home() {
  print_message "Delete home…"

  rm -rf $VPNM_HOME

  print_message "✔ Home deleted."
}

check_requirements() {
  print_message "Check requirements…"

  if [ "$VPNM_ALLOW_SSH" = true ] && ! [ -x "$(command -v ssh)" ]; then
    print_error "\e[1mssh\e[22m command is not available in your system."
    exit 101
  fi

  if [ "$VPNM_ALLOW_SSH" = true ] && ! [ -x "$(command -v ssh-keygen)" ]; then
    print_error "\e[1mssh-keygen\e[22m command is not available in your system."
    exit 101
  fi

  if ! [ -x "$(command -v drill)" ]; then
    print_error "\e[1mdrill\e[22m command is not available in your system."
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

  if ! [ -x "$(command -v sudo)" ]; then
    print_error "\e[1msudo\e[22m command is not available in your system."
    exit 101
  fi

  if [ -z "$1" ]; then
    print_warn "No arguments supplied. Valid arguments are: start|stop|status"
    exit 1
  fi

  print_message "✔ Requirements checked."
}

print_message() {
  echo -e " 🠒 $1"
}

print_error() {
  echo -e "\e[91m 🗶 $1\e[39m" >&2
}

print_warn() {
  echo -e "\e[93m ❕ $1\e[0m" >&2
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
  echo "--os                      what underlying OS to use, supported: ubuntu, alpine"
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
    --os)
      shift
      if [ "$1" != "alpine" ] && [ "$1" != "ubuntu" ]; then
        print_warn "Unsupported OS."
        exit 1
      fi
      if test $# -gt 0 ; then
        export VPNM_OS=$1
        export VPNM_SSH_USER=$1
        if [ "$1" == "alpine" ]; then
          VPNM_OS_POSTROUTING_INTERFACE="eth0"
        fi
      else
        print_warn "No OS name specified."
        exit 1
      fi
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
  print_message "To connect to the $VPNM_APPLICATION_NAME server with SSH, use:"

  print_message "  $ ssh -i $VPNM_SSH_KEY_FILE -o UserKnownHostsFile=$VPNM_SSH_KNOWN_HOST_FILE $VPNM_SSH_USER@$VPNM_WG_SERVER_PUBLIC_IP"
}

create_ssh_key() {
  print_message "Generate SSH key..."

  if [ ! -f $VPNM_SSH_KEY_FILE ]; then
    ssh-keygen -t rsa -b 4096 -f $VPNM_SSH_KEY_FILE -C "$VPNM_APPLICATION_NAME" -q -N ""

    print_message "✔ SSH key generated."
  else
    print_message "✔ SSH key already generated."
  fi

  export VPNM_SSH_PUBLIC_KEY=$(ssh-keygen -y -f $VPNM_SSH_KEY_FILE)
}

delete_ssh_key() {
  print_message "Delete SSH key..."

  rm -f $VPNM_SSH_KEY_FILE $VPNM_SSH_KEY_FILE.pub

  print_message "✔ SSH key deleted."
}

####
# VPN
####

generate_wireguard_keys() {
  print_message "Generate wireguard keys..."

  if [ ! -f "$VPNM_WG_SERVER_CONFIG_FILE" ]; then
    export VPNM_WG_SERVER_KEY=$(wg genkey)
    export VPNM_WG_SERVER_PUBLIC_KEY=$(echo "$VPNM_WG_SERVER_KEY" | wg pubkey)
    print_message "✔ wireguard server keys generated."
  else
    print_message "✔ wireguard server keys already generated."
  fi

  if [ ! -f "$VPNM_WG_CLIENT_CONFIG_FILE" ]; then
    export VPNM_WG_CLIENT_KEY=$(wg genkey)
    export VPNM_WG_CLIENT_PUBLIC_KEY=$(echo "$VPNM_WG_CLIENT_KEY" | wg pubkey)
    print_message "✔ wireguard client keys generated."
  else
    print_message "✔ wireguard client keys already generated."
  fi
}

generate_wireguard_test_configuration() {
  print_message "Generate wireguard test configuration..."

  if [ ! -f "$VPNM_WG_TEST_CONFIG_FILE" ]; then
    local ip_check_host_ips=$(drill -D -4 A ifconfig.me | grep -Po '([\.0-9]{2,5}){3}$' | sed '$ d' | sed 's/$/\/32/' | paste -sd ",")

    local wg_test_config="[Interface]\\n\
Address = 192.168.2.2\\n\
PrivateKey = $VPNM_WG_CLIENT_KEY\\n\
\\n\
[Peer]\\n\
PublicKey = $VPNM_WG_SERVER_PUBLIC_KEY\\n\
AllowedIPs = $ip_check_host_ips\\n\
Endpoint = $VPNM_WG_SERVER_PUBLIC_IP:51820"
    umask 066
    echo -e "$wg_test_config" > "$VPNM_WG_TEST_CONFIG_FILE"
    print_message "✔ wireguard test configuration generated."
  else
    print_message "✔ wireguard test configuration already generated."
  fi
}

generate_wireguard_client_configuration() {
  print_message "Generate wireguard client configuration..."

  if [ ! -f "$VPNM_WG_CLIENT_CONFIG_FILE" ]; then
    local wg_client_config="[Interface]\\n\
Address = 192.168.2.2\\n\
PrivateKey = $VPNM_WG_CLIENT_KEY\\n\
\\n\
[Peer]\\n\
PublicKey = "$VPNM_WG_SERVER_PUBLIC_KEY"\\n\
AllowedIPs = 0.0.0.0/0, ::/0\\n\
Endpoint = $VPNM_WG_SERVER_PUBLIC_IP:51820"
    umask 066
    echo -e "$wg_client_config" > $VPNM_WG_CLIENT_CONFIG_FILE
    print_message "✔ wireguard client configuration generated."
  else
    print_message "✔ wireguard client configuration already generated."
  fi
}

generate_wireguard_server_configuration() {
  print_message "Generate wireguard client configuration..."

  if [ ! -f "$VPNM_WG_SERVER_CONFIG_FILE" ]; then
    local wg_server_config="[Interface]\\n\
Address = 192.168.2.1 \\n\
PrivateKey = $VPNM_WG_SERVER_KEY\\n\
ListenPort = 51820\\n\
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $VPNM_OS_POSTROUTING_INTERFACE -j MASQUERADE\\n\
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $VPNM_OS_POSTROUTING_INTERFACE -j MASQUERADE\\n\
[Peer]\\n\
PublicKey = $VPNM_WG_CLIENT_PUBLIC_KEY\\n\
AllowedIPs = 192.168.2.2/32"
    umask 066
    echo -e "$wg_server_config" > "$VPNM_WG_SERVER_CONFIG_FILE"
    print_message "✔ wireguard server configuration generated."
  else
    print_message "✔ wireguard server configuration already generated."
  fi
}

delete_wireguard_configurations() {
  print_message "Delete wireguard configuration..."

  rm -f $VPNM_WG_CLIENT_CONFIG_FILE
  rm -f $VPNM_WG_SERVER_CONFIG_FILE

  print_message "✔ wireguard configuration deleted."
}

wait_vpn_connectivity() {
  print_message "   ### Wait for VPN to be ready..."

  local ip_check_host_ips=$(drill -D -4 A ifconfig.me | grep -Po '([\.0-9]{2,5}){3}$' | sed '$ d' | sed 's/$/\/32/' | paste -sd ",")

  start_client_wireguard "$VPNM_WG_TEST_CONFIG_FILE"

  while ! is_connected; do
    sleep 2
  done

  stop_client_wireguard "$VPNM_WG_TEST_CONFIG_FILE" "$VPNM_WG_TEST_CONFIG_NAME"

  print_message " ✔ ### VPN is ready."
}

is_connected() {
  if [ "$(curl -s --max-time 1 ifconfig.me/ip)" == "$VPNM_WG_SERVER_PUBLIC_IP" ]; then
    return 0
  else
    return 1
  fi
}

start_client_wireguard() {
  print_message "Start wireguard…"

  local configuration_file=${1:-$VPNM_WG_CLIENT_CONFIG_FILE}
  local configuration_name=${2:-$VPNM_WG_CLIENT_CONFIG_NAME}

  if [ ! -f "$configuration_file" ]; then
    print_error "Error: cannot start wireguard client. No such file: \e[1m$configuration_file\e[22m."
  fi

  local wg_is_up=$(sudo -E wg show "$configuration_name" >&/dev/null && echo 1 || echo 0)
  if [ "$wg_is_up" -eq 0 ]; then
    sudo -E wg-quick up "$configuration_file"
    print_message "✔ wireguard started."
  else
    print_message "✔ wireguard already running."
  fi
}

stop_client_wireguard() {
  print_message "Stop wireguard…"

  local configuration_file=${1:-$VPNM_WG_CLIENT_CONFIG_FILE}
  local configuration_name=${2:-$VPNM_WG_CLIENT_CONFIG_NAME}

  local wg_is_up=$(sudo -E wg show "$configuration_name" >&/dev/null && echo 1 || echo 0)
  if [ -f "$configuration_file" ] && [ "$wg_is_up" -eq 1 ]; then
    sudo -E wg-quick down "$configuration_file"
    print_message "✔ wireguard stopped."
  else
    print_message "✔ wireguard not running."
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
  print_message "Deploy infrastructure..."

  mkdir -p "$TF_DATA_DIR"

  case $VPNM_PROVIDER in
  aws)
    HOME=$VPNM_HOME terraform init "$VPNM_CODE_TERRAFORM_PATH/aws"
    HOME=$VPNM_HOME terraform apply -state="$TF_STATE_FILE" -state-out="$TF_STATE_FILE" -auto-approve -var "ami_os=$VPNM_OS" -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "base64_vpn_server_config=$(base64 $VPNM_WG_SERVER_CONFIG_FILE)" -var "application_name=$VPNM_APPLICATION_NAME" -var "allow_ssh=$VPNM_ALLOW_SSH" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" "$VPNM_CODE_TERRAFORM_PATH/aws"

    print_message "Waiting for SSH..."

    if [ "$VPNM_ALLOW_SSH" = true ]; then
      while [ "$(HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq '.ssh_known_hosts.value' | sed s/\"//g)" == "IN PROGRESS..." ]; do
        HOME=$VPNM_HOME terraform refresh -state=$TF_STATE_FILE -var "region=$AWS_DEFAULT_REGION" -var "public_key=$VPNM_SSH_PUBLIC_KEY" -var "base64_vpn_server_config=$(base64 $VPNM_WG_SERVER_CONFIG_FILE)" -var "application_name=$VPNM_APPLICATION_NAME" -var "allow_ssh=$VPNM_ALLOW_SSH" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" "$VPNM_CODE_TERRAFORM_PATH/aws"
        sleep 4
      done
    fi

    print_message "✔ SSH ready."

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

  print_message "✔ infrastructure deployed."
}

destroy_infrastructure() {
  print_message "Destroy infrastructure..."

  mkdir -p $TF_DATA_DIR

  case $VPNM_PROVIDER in
  aws)
    local already_used_region="$(HOME=$VPNM_HOME terraform output -state=$TF_STATE_FILE -json | jq '.region.value' | sed s/\"//g)"

    if [ -f "$TF_STATE_FILE" ]; then
      HOME=$VPNM_HOME terraform destroy -force -state=$TF_STATE_FILE -state-out=$TF_STATE_FILE -auto-approve -var "destroy=true" -var "region=${already_used_region:+$AWS_DEFAULT_REGION}" -var "public_key=''" -var "base64_vpn_server_config=" -var "shared_credentials_file=$AWS_CREDENTIAL_FILE" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_ACCESS_KEY" "$VPNM_CODE_TERRAFORM_PATH/aws"
    fi
    ;;
  *)
    print_error "\e[1m$VPNM_PROVIDER\e[22m is not supported yet. Pull requests are welcomed."
    exit 1
    ;;
  esac

  rm -rf $TF_DATA_DIR

  print_message "✔ infrastructure destroyed."
}

check_status() {
  print_message "Check wireguard server status"

  printf "Connection: "
  if is_connected ; then
    echo "$VPNM_WG_SERVER_PUBLIC_IP"
  else
    echo "not connected"
  fi

  if [ "$VPNM_ALLOW_SSH" = true ]; then
    printf "SSH: "
    ssh -i $VPNM_SSH_KEY_FILE -o UserKnownHostsFile=$VPNM_SSH_KNOWN_HOST_FILE -o ConnectionAttempts=10 "$VPNM_SSH_USER"@"$VPNM_WG_SERVER_PUBLIC_IP" echo 'SSH is working'
  fi

  print_message "✔ wireguard server status checked."
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
    generate_wireguard_test_configuration
    generate_wireguard_client_configuration
    if ! is_connected; then
      wait_vpn_connectivity
    fi
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
    stop_client_wireguard "$VPNM_WG_TEST_CONFIG_FILE" "$VPNM_WG_TEST_CONFIG_NAME"
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
    print_warn "\e[1mstatus\e[22m is not implemented yet."
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
