#!/bin/bash

# Create the database and import the Senzing schema if it doesn't already exist.
if psql -lqt | cut -d \| -f 1 | grep -qw G2; then
    echo "Database has already been initialized"
else
    echo "Initializing Senzing database"
    createdb G2
    psql -d G2 -f /opt/senzing/er/resources/schema/szcore-schema-postgresql-create.sql
fi
