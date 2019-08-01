#!/bin/bash

ENGINE_URL="https://rhvm.lab.example.com/ovirt-engine"
USER_NAME="admin@internal"
USER_PASSW="redhat"
#CA_CERT_PATH=/root/RHVM_API_Lab/Ansible/apache-ca.pem

HEADER_CONTENT_TYPE="Content-Type: application/xml"
HEADER_ACCEPT="Accept: application/xml"
COMM_FILE="/tmp/restapi_com.xml"
STAT_FILE="/tmp/restapi_stat.xml"
FILE_BEST_HOST="/tmp/best_hypervisor.yml"
FILE_BEST_STORAGE="/tmp/best_storage.yml"
BEST_PLACE=""
BEST_MEMFREE=0
BEST_STORAGE=""
BEST_FREESTORAGE=0

#Clear files
>$COMM_FILE
>$STAT_FILE
>$FILE_BEST_HOST
>$FILE_BEST_STORAGE

declare -A hosts_list
declare -A storage_list

function _fill_best_placement_memory {
	for hosts in $(seq 1 $count_host)
	do
		if [ ${hosts_list[$hosts,2]} -gt $BEST_MEMFREE ]
		then
			BEST_MEMFREE=${hosts_list[$hosts,2]}
			BEST_PLACE=${hosts_list[$hosts,1]}
		fi
	done
}

function _fill_best_placement_storage {
	for stdom in $(seq 1 $count_storage)
	do
		if [ ${storage_list[$stdom,2]} == "data" ]
		then
			if [ ${storage_list[$stdom,1]} -gt $BEST_FREESTORAGE ]
			then
				BEST_FREESTORAGE=${storage_list[$stdom,1]}
				BEST_STORAGE=${storage_list[$stdom,0]}
			fi
		fi
	done
}

function _get_apiservice {
	local uri=$1
	#curl -X GET -H "${HEADER_ACCEPT}" -H "${HEADER_CONTENT_TYPE}" -u "${USER_NAME}:${USER_PASSW}" --cacert "${CA_CERT_PATH}" "${ENGINE_URL}${uri}" --output "${2}" 2> /dev/null > "${2}"
	curl -X GET -H "${HEADER_ACCEPT}" -H "${HEADER_CONTENT_TYPE}" -u "${USER_NAME}:${USER_PASSW}" --insecure "${ENGINE_URL}${uri}" --output "${2}" 2> /dev/null > "${2}"
}

function _get_hosts_stats {
	hosts_list[$1,2]=$(xmllint "${STAT_FILE}" --xpath '//statistics/statistic[3]/values/value/datum/text()')
}

function _get_href_and_name {
	count_host=$(xmllint "${COMM_FILE}" --xpath 'count(//hosts/host)')
	for hosts in $(seq 1 $count_host)
	do
		# Get Host URI
		hosts_list[$hosts,0]=$(xmllint "${COMM_FILE}" --xpath '//hosts/host['$hosts']/@href' | sed 's/ href="\/ovirt-engine\([^"]*\)"/\1\n/g')
		# Get Host Name
		hosts_list[$hosts,1]=$(xmllint "${COMM_FILE}" --xpath '//hosts/host['$hosts']/name/text()')
		# Call statistics function, arg: URI + FileOutput
		_get_apiservice "${hosts_list[$hosts,0]}/statistics" "${STAT_FILE}"
		_get_hosts_stats $hosts
	done
	
	_fill_best_placement_memory
}

function _get_storage_info {
	count_storage=$(xmllint "${COMM_FILE}" --xpath 'count(//storage_domain)')
	for stdom in $(seq 1 $count_storage)
	do
		# Get Storage Domain Name
		storage_list[$stdom,0]=$(xmllint "${COMM_FILE}" --xpath '//storage_domain['$stdom']/name/text()')
		# Get Storage Domain Available
		storage_list[$stdom,1]=$(xmllint "${COMM_FILE}" --xpath '//storage_domain['$stdom']/available/text()')
		# Get Storage Type
		storage_list[$stdom,2]=$(xmllint "${COMM_FILE}" --xpath '//storage_domain['$stdom']/type/text()')
	done

	_fill_best_placement_storage
}

_get_apiservice "/api/hosts" "${COMM_FILE}"
_get_href_and_name
_get_apiservice "/api/storagedomains" "${COMM_FILE}"
_get_storage_info

#echo $BEST_MEMFREE
echo "rhvhost: "$BEST_PLACE >> $FILE_BEST_HOST
#	echo $BEST_FREESTORAGE
echo "storage_domain: "$BEST_STORAGE >> $FILE_BEST_STORAGE
