#!/usr/bin/env sh

VPN_MINUTE_AWS_COMMAND=aws

set -e
#set -x

check_requirments()
{
	if ! [ -x "$(command -v ${VPN_MINUTE_AWS_COMMAND})" ]; then
		echo "Error: ${VPN_MINUTE_AWS_COMMAND} is not installed." >&2
		exit 100
	fi

		if ! [ -x "$(command -v jq)" ]; then
		echo "Error: jq is not installed." >&2
		exit 101
	fi

	if ! $(${VPN_MINUTE_AWS_COMMAND} configure get aws_access_key_id &> /dev/null); then
		echo "Cannot load credentials. Please run ${VPN_MINUTE_AWS_COMMAND} manually to fix the issue." >&2
		exit 90
	fi

	if [ -z "$1" ]; then
		echo "No arguments supplied. Valid arguments are: start|stop|status" >&2
		exit 1
	fi

	echo -e "-> Requirements checked."
}

####
# AWS
####

get_available_regions()
{
	cat <<-END
		usa:us-east-1
		hkg:ap-east-1
		ind:ap-south-1
		kor:ap-northeast-2
		spg:ap-southeast-1
		aus:ap-southeast-2
		jpn:ap-northeast-1
		$can:ca-central-1
		chn:cn-north-1
		deu:eu-central-1
		irl:eu-west-1
		gbr:eu-west-2
		fra:eu-west-3
		swe:eu-north-1
		bra:sa-east-1
END
}

find_image()
{
	check_requirments "$@"
}

create_security_group()
{
	check_requirments "$@"
}

destroy_security_group()
{
	check_requirments "$@"
}

find_security_group()
{
	check_requirments "$@"
}

find_vpc()
{
	echo $(${VPN_MINUTE_AWS_COMMAND} ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r  '.Vpcs[0] .VpcId')
}


search_image()
{
	check_requirments "$@"
}

####
# Main
####

main()
{
	check_requirments "$@"
	#find_vpc
	get_available_regions
}

main "$@"
