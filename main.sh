#!/usr/bin/env sh

PROGRAM_NAME="vpn-minute"

set -e
#set -x

check_requirments()
{
    if ! [ -x "$(command -v ssh-keygen)" ]; then
		echo "Error: openssh-client is not installed." >&2
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

	if [ -z "$1" ]; then
		echo "No arguments supplied. Valid arguments are: start|stop|status" >&2
		exit 1
	fi    

	echo -e "-> Requirements checked."
}

check_arguments()
{
  export PROVIDER=aws
  export REGION=ca-central-1
  export TF_DATA_DIR=/var/tmp/tobechange

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
        break
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
 
  ssh-keygen -t rsa -b 4096 -f /tmp/toberandom -C "vpn-minute" -q -N ""
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
      terraform apply -auto-approve -var "region=$REGION" -var "public_key=$SSH_PUBLIC_KEY" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_KEY" terraform/aws
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
      terraform destroy -auto-approve -var "region=$REGION" -var "public_key=''" -var "access_key=$AWS_ACCESS_KEY" -var "secret_key=$AWS_SECRET_KEY" terraform/aws
    ;;
    *)
      echo "Error: $PROVIDER is not supported yet."
      exit 1
    ;;
  esac

  echo -e "-> infratructure deployed."
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
    ;;
    stop)
      destroy_terraform
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
