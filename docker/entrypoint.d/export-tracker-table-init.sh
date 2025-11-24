#!/bin/bash

if psql -lqt | cut -d \| -f 1 | grep -qw sqs_entity_resolution; then
    echo "Export tracker table has already been initialized."
else
    echo "Initializing export tracker table."
    psql -d G2 -f /create-export-tracker-table.sql
fi
