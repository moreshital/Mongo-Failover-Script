#!/bin/bash

MIG_NAME=mongo-multi-az
PRI_DISK=mongo-a
SEC_DISK=mongo-b
# NEW_DISK_NAME=
# SOURCE_SNAPSHOT=snap_name-`date +%d-%m-%Y`
ZONE_A=asia-southeast1-a
ZONE_B=asia-southeast1-b
#MIN_SIZE=`gcloud compute instance-groups managed   describe #${MIG_NAME} --zone=${ZONE} | grep minNumReplicas | cut -d ':' -f2`

INSTANCES=`gcloud compute instance-groups managed list-instances ${MIG_NAME} --zone asia-southeast1-a | awk {'print $1'} | tail -n +2|wc -l`
    echo "Needs to handle Failover"

    HOSTNAME=`hostname`

#Attach existing disk of terminated NODE
   # gcloud compute instances attach-disk ${HOSTNAME} --disk=${PRI_DISK} --zone ${ZONE_A}
   # gcloud compute instances attach-disk ${HOSTNAME} --disk=${SEC_DISK} --zone ${ZONE_B}

#calculate IP of newly launched instance and instances running in mongo cluster
    NEW_SEC_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip`
    MONGO_IPS=`gcloud compute instances list --filter="NAME:'mongo-multi'" --format="value(networkInterfaces[0].networkIP)"`
    # sudo mount /dev/sdb /mongodata
    sudo chown -R mongodb:mongodb /mongodata
    sudo systemctl start mongodb.service
    export NEW_SEC_IP=$NEW_SEC_IP
    j=0
    for i in ${MONGO_IPS}
    do
       MASTER=`sudo -u ubuntu ssh ubuntu@$i 'mongo --quiet --eval "d=db.isMaster().primary;"'`
       RANGE=`sudo -u ubuntu ssh ubuntu@$i 'mongo --quiet --eval "rs.status().members[2]._id"'`

       while [ "$j" -le "$RANGE" ]
       do
	        echo $j
	        echo "in j"
          STATE=`sudo -u ubuntu ssh ubuntu@$i 'mongo --quiet --eval "rs.status().members['$j'].stateStr"'`
         echo "STATE=" $STATE
       if [[ "$STATE" == '(not reachable/healthy)' ]]
        then
        INST_NAME=`sudo -u ubuntu ssh ubuntu@$i 'mongo --quiet --eval "rs.status().members['$j'].name"'`

       echo ${MASTER}
       MASTER_IP=`echo ${MASTER} | cut -d ':' -f1`
       sudo -u ubuntu ssh ubuntu@${MASTER_IP} 'mongo' << HERE
         rs.remove("${INST_NAME}")
         use admin
         db.auth("mongo", "mongo123")
         rs.addArb("${HOSTNAME}")
HERE
        CONF=`sudo -u ubuntu ssh ubuntu@${MASTER_IP} 'mongo' << HERE
rs.conf()
HERE
`
# insert conf to arb
sudo -u ubuntu ssh ubuntu@${NEW_SEC_IP} 'mongo' << HERE
use local
db.system.replset.remove({})
db.system.replset.insert(${CONF})
HERE

       break
     fi
     j=$(($j + 1))
     done
  done
