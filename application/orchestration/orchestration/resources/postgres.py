"""PostgreSQL resource configuration."""

import os
from dagster import resource
import psycopg2
from psycopg2.extras import RealDictCursor


@resource
def postgres_resource(context):
    """PostgreSQL connection resource."""
    conn_params = {
        "host": os.getenv("POSTGRES_HOST", "localhost"),
        "port": int(os.getenv("POSTGRES_PORT", "5432")),
        "database": os.getenv("POSTGRES_DB", "dataplatform"),
        "user": os.getenv("POSTGRES_USER", "dataplatform"),
        "password": os.getenv("POSTGRES_PASSWORD", "dataplatform"),
    }
    
    connection = psycopg2.connect(**conn_params, cursor_factory=RealDictCursor)
    
    try:
        yield connection
    finally:
        connection.close()