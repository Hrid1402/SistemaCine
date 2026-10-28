import os
import boto3
import json
import psycopg2

def lambda_handler(event, context):
    # Obtiene el nombre del secreto y la región desde las variables de entorno configuradas en Terraform
    secret_name = os.environ['DB_SECRET_NAME']
    region_name = os.environ['AWS_REGION']

    # Se conecta a AWS Secrets Manager para recuperar las credenciales seguras de RDS de forma dinámica
    client = boto3.client('secretsmanager', region_name=region_name)
    secret = json.loads(client.get_secret_value(SecretId=secret_name)['SecretString'])

    # Establece la conexión física con la base de datos PostgreSQL en RDS utilizando las credenciales obtenidas
    conn = psycopg2.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret.get('port', 5432),
        connect_timeout=10
    )
    cursor = conn.cursor()

    # Ejecuta sentencias SQL para crear las tablas movies y payments
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS movies (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            poster_key VARCHAR(255) NOT NULL
        );
        CREATE TABLE IF NOT EXISTS payments (
            id SERIAL PRIMARY KEY,
            idempotency_key VARCHAR(255) UNIQUE NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            status VARCHAR(50) NOT NULL
        );
        INSERT INTO movies (title, poster_key)
        VALUES ('Oppenheimer', 'posters/poster_oppenheimer.jpg')
        ON CONFLICT DO NOTHING;
    """)
    
    # Confirma los cambios en la base de datos
    conn.commit()
    # Cierra el cursor y la conexión para liberar recursos de red y memoria
    cursor.close()
    conn.close()

    return {"statusCode": 200, "body": "Base de datos inicializada correctamente."}
