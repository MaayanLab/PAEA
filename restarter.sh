#!/bin/sh
while true; do
	sleep 30
	n_error_logs=$(ls /var/log/shiny-server | wc -l)
	if [[ n_error_logs > 1 ]]; then 
		# if error log is written, restart app 
		wget -O- --post-data='{"force": false}' \
			--header=Content-Type:application/json \
			"http://$USERNAME:$PASSWORD@146.203.54.165:8080/v2/apps//paea/restart"
		exit;
	fi
done
