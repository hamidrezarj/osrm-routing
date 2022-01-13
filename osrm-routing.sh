#! /bin/bash

# This script feeds traffic.csv file into osrm and loads it into shared memory.

# algorithm='CH'
osm_CH_data='CH/iran-latest.osm.pbf'
osm_MLD_data='MLD/iran-latest.osm.pbf'
osrm_CH_data='CH/iran-latest.osrm'
osrm_MLD_data='MLD/iran-latest.osrm'

while getopts "et:ra:d:o:cslk" OPTION; do
    case "$OPTION" in
        a)
            echo "--algorithm: $OPTARG" >> osrm-routing.log
            algorithm=$OPTARG
            ;;

        e) 
            echo "--extract" >> osrm-routing.log
            extract=true
            ;;

        t)
            echo "--traffic" >> osrm-routing.log

            if [ ! -f "$OPTARG" ]; then 
                echo 'parameter is not file' >> osrm-routing.log
            fi

            traffic=true
            traffic_file=$OPTARG
            ;;

        c)
            echo "--contract" >> osrm-routing.log
            contract=true
            ;;

        r)
            echo "--osrm-routed"
            osrm_routed=true
            ;;
        d)
            echo "--data: $OPTARG" >> osrm-routing.log
            osm_data=$OPTARG
            
            # convert .osm to .osrm
            IFS='.'                         # dot is set as delimiter
            read -ra ADDR <<< "$OPTARG"     # str is read into an array as tokens separated by IFS

            if [[ $algorithm = "CH" ]]; then
                osrm_CH_data = "CH/"

                osrm_CH_data=${ADDR[0]}
                IFS=' '

                for (( i=1; i<${#ADDR[@]}; i++ )); do

                    if [[ ${ADDR[$i]} == "osm" ]]; then
                        break
                    fi

                    osrm_CH_data+=".${ADDR[$i]}";

                done

                osrm_CH_data+=".osrm"
            else

                osrm_MLD_data = "MLD/"

                osrm_MLD_data=${ADDR[0]}
                IFS=' '

                for (( i=1; i<${#ADDR[@]}; i++ )); do

                    if [[ ${ADDR[$i]} == "osm" ]]; then
                        break
                    fi

                    osrm_MLD_data+=".${ADDR[$i]}";

                done

                osrm_MLD_data+=".osrm"
            fi
            ;;
            # osrm_data=${ADDR[0]}
            # IFS=' '

            # for (( i=1; i<${#ADDR[@]}; i++ )); do

            #     if [[ ${ADDR[$i]} == "osm" ]]; then
            #         break
            #     fi

            #     osrm_data+=".${ADDR[$i]}";

            # done

            # osrm_data+=".osrm"
        o)
            echo "--osrm-data: $OPTARG" >> osrm-routing.log
            osrm_data=$OPTARG
            ;;

        s)
            echo "--osrm-datastore" >> osrm-routing.log
            osrm_datastore=true
            ;;
        
        l)
            echo "--run osrm-routed from shared memory" >> osrm-routing.log
            shared_memory=true
            ;;
        
        k)
            echo "--kill all osrm commands except osrm-routed" >> osrm-routing.log
            kill_osrm=true
            ;;

    esac
done

# check if algorithm type is provided.
if [[ $algorithm = "MLD" ]]; then
    osm_data=$osm_MLD_data
    osrm_data=$osrm_MLD_data
    dataset_name="iran-osm-MLD"
elif [[ $algorithm = "CH" ]]; then
    osm_data=$osm_CH_data
    osrm_data=$osrm_CH_data
    dataset_name="iran-osm-CH"
else
    echo "provided algorithm is wrong"
    exit
fi

# clear log file first.
echo "" > osrm-routing.log

if [[ $extract = true ]]; then 

    echo '-------------------- osrm-extract ---------------------' >> osrm-routing.log
    osrm-extract -p /srv/osrm/osrm-backend/profiles/car.lua $osm_data 2>&1 | tee -a osrm-routing.log
fi

if [[ $algorithm = "CH" && ( $traffic = true || $contract = true )]]; then

    echo '-------------------- osrm-contract ---------------------' >> osrm-routing.log
    echo 'before_time: ' >> osrm-routing.log
    date 2>&1 | tee -a osrm-routing.log

    if [ "$traffic" = true ]; then
        osrm-contract $osrm_data --segment-speed-file $traffic_file 2>&1 | tee -a osrm-routing.log
    else
        osrm-contract $osrm_data --threads=8 2>&1 | tee -a osrm-routing.log
    fi

    echo 'after_time: ' >> osrm-routing.log
    date 2>&1 | tee -a osrm-routing.log
fi

if [[ $algorithm = "MLD" && ( $traffic = true || $contract = true )]]; then
    
    echo '-------------------- osrm-partition ---------------------' >> osrm-routing.log
    echo 'before_time: ' >> osrm-routing.log
    date 2>&1 | tee -a osrm-routing.log
    osrm-partition $osrm_data 2>&1 | tee -a osrm-routing.log

    echo '-------------------- osrm-customize ---------------------' >> osrm-routing.log

    if [ "$traffic" = true ]; then
        osrm-customize $osrm_data --segment-speed-file $traffic_file 2>&1 | tee -a osrm-routing.log
    else
        osrm-customize $osrm_data --threads=8 2>&1 | tee -a osrm-routing.log
    fi

    echo 'after_time: ' >> osrm-routing.log
    date 2>&1 | tee -a osrm-routing.log
fi

if [[ $osrm_datastore = true ]]; then

    echo '-------------------- osrm-datastore ---------------------' >> osrm-routing.log
    osrm-datastore --dataset-name=$dataset_name $osrm_data 2>&1 | tee -a osrm-routing.log
fi

if [[ $osrm_routed = true ]]; then
    
    echo "-------------------- osrm-routed ---------------------" >> osrm-routing.log

    if [[ $shared_memory = true ]]; then
        osrm-routed --algorithm=$algorithm --dataset-name=$dataset_name --shared-memory 2>&1 | tee -a osrm-routing.log
    else
        osrm-routed --algorithm=$algorithm $osrm_data 2>&1 | tee -a osrm-routing.log
    fi
fi

if [[ $kill_osrm = true ]]; then
    
    echo "-------------------- killing osrm commands except osrm-routed ---------------------" >> osrm-routing.log

    pkill -9 osrm-partition
    pkill -9 osrm-datastore
    pkill -9 osrm-customize
    pkill -9 osrm-contract
    pkill -9 osrm-extract 
fi
