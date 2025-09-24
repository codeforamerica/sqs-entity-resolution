#!/bin/bash

# Crearte data sources if SENZING_DATASOURCES environment variable is set.
if [[ -n "${SENZING_DATASOURCES}" ]]; then
  echo "Creating data sources"
  > /home/senzing/data-sources.txt

  IFS=" " read -r -a data_sources <<< "$SENZING_DATASOURCES"
  for ds in "${data_sources[@]}"; do
    echo "addDataSource ${ds}" >> /home/senzing/data-sources.txt
  done

  echo "save" >> /home/senzing/data-sources.txt
  sz_configtool -f /home/senzing/data-sources.txt
  rm /home/senzing/data-sources.txt
fi
