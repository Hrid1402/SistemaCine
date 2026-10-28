import os
import boto3
import json
import psycopg2

def lambda_handler(event, context):
    secret_name = os.environ['DB_SECRET_NAME']
    region_name = os.environ['AWS_REGION']

    # Recupera credenciales desde AWS Secrets Manager
    client = boto3.client('secretsmanager', region_name=region_name)
    secret = json.loads(client.get_secret_value(SecretId=secret_name)['SecretString'])

    conn = psycopg2.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret.get('port', 5432),
        connect_timeout=10
    )
    cursor = conn.cursor()

    # Crea tablas y asegura columnas para sala, precio y cantidad de asientos
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS movies (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            poster_key VARCHAR(255) NOT NULL,
            price DECIMAL(10, 2) NOT NULL DEFAULT 15.00,
            room VARCHAR(50) NOT NULL DEFAULT 'Sala 1 - 2D',
            total_seats INT NOT NULL DEFAULT 30
        );

        ALTER TABLE movies ADD COLUMN IF NOT EXISTS price DECIMAL(10, 2) NOT NULL DEFAULT 15.00;
        ALTER TABLE movies ADD COLUMN IF NOT EXISTS room VARCHAR(50) NOT NULL DEFAULT 'Sala 1 - 2D';
        ALTER TABLE movies ADD COLUMN IF NOT EXISTS total_seats INT NOT NULL DEFAULT 30;

        CREATE TABLE IF NOT EXISTS payments (
            id SERIAL PRIMARY KEY,
            idempotency_key VARCHAR(255) UNIQUE NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            status VARCHAR(50) NOT NULL
        );

        INSERT INTO movies (id, title, poster_key, price, room, total_seats)
        VALUES 
            (1, 'Oppenheimer', 'posters/poster_oppenheimer.jpg', 15.00, 'Sala 1 - 2D', 30),
            (2, 'La Red Social', 'posters/poster_la_red_social.png', 12.50, 'Sala 2 - 2D', 30)
        ON CONFLICT (id) DO UPDATE 
        SET title = EXCLUDED.title,
            poster_key = EXCLUDED.poster_key,
            price = EXCLUDED.price,
            room = EXCLUDED.room,
            total_seats = EXCLUDED.total_seats;
    """)
    
    conn.commit()
    cursor.close()
    conn.close()

    return {"statusCode": 200, "body": json.dumps({"message": "Base de datos inicializada correctamente con películas, salas y precios."})}
