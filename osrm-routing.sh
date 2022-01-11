#! /bin/bash

# This script feeds traffic.csv file into osrm and loads it into shared memory.

algorithm='CH'
osm_data='iran-latest.osm.pbf'
osrm_data='iran-latest.osrm'

while getopts "et:ra:d:o:csl" OPTION; do
    case "$OPTION" in
        e) 
            echo "--extract"
            extract=true
            ;;

        t)
            echo "--traffic"

            if [ ! -f "$OPTARG" ]; then 
                echo 'parameter is not file'
            fi

            traffic=true
            traffic_file=$OPTARG
            ;;

        c)
            echo "--contract"
            contract=true
            ;;

        r)
            echo "--osrm-routed"
            osrm_routed=true
            ;;

        a)
            echo "--algorithm: $OPTARG"
            algorithm=$OPTARG
            ;;
        
        d)
            echo "--data: $OPTARG"
            osm_data=$OPTARG
            
            # convert .osm to .osrm
            IFS='.'                         # dot is set as delimiter
            read -ra ADDR <<< "$OPTARG"     # str is read into an array as tokens separated by IFS
            osrm_data=${ADDR[0]}
            IFS=' '

            for (( i=1; i<${#ADDR[@]}; i++ )); do

                if [[ ${ADDR[$i]} == "osm" ]]; then
                    break
                fi

                osrm_data+=".${ADDR[$i]}";

            done

            osrm_data+=".osrm"
            ;;

        o)
            echo "--osrm-data: $OPTARG"
            osrm_data=$OPTARG
            ;;

        s)
            echo "--osrm-datastore"
            osrm_datastore=true
            ;;
        
        l)
            echo "--run osrm-routed from shared memory"
            shared_memory=true
            ;;
        

    esac
done

echo "osrm-data: $osrm_data"

if [[ $extract = true ]]; then 
    echo '-------------------- osrm-extract ---------------------'
    osrm-extract -p /srv/osrm/osrm-backend/profiles/car.lua $osm_data
fi

if [[ $algorithm = "CH" && ( $traffic = true || $contract = true )]]; then
    echo '-------------------- osrm-contract ---------------------'
    echo 'before_time: '
    date

    if [ "$traffic" = true ]; then
        osrm-contract $osrm_data --segment-speed-file $traffic_file
    else
        osrm-contract $osrm_data --threads=8
    fi

    echo 'after_time: '
    date

elif [[ $algorithm = "MLD" && ( $traffic = true || $contract = true )]]; then
    echo '-------------------- osrm-partition ---------------------'
    echo 'before_time: '
    date
    osrm-partition $osrm_data

    echo '-------------------- osrm-customize ---------------------'

    if [ "$traffic" = true ]; then
        osrm-customize $osrm_data --segment-speed-file $traffic_file
    else
        osrm-customize $osrm_data --threads=8
    fi

    echo 'after_time: '
    date
fi

if [[ $osrm_datastore = true ]]; then
    echo '-------------------- osrm-datastore ---------------------'
    osrm-datastore --dataset-name=iran-osm $osrm_data
fi

if [[ $osrm_routed = true ]]; then
    echo '-------------------- osrm-routed ---------------------'

    if [[ $shared_memory = true ]]; then
        osrm-routed --algorithm=$algorithm --dataset-name=iran-osm --shared-memory 
    else
        osrm-routed --algorithm=$algorithm $osrm_data
    fi
fi








