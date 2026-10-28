import os
import boto3
import json
import psycopg2
from botocore.client import Config

def lambda_handler(event, context):
    # Carga las variables de entorno definidas en Terraform de RDS y bucket S3
    secret_name = os.environ['DB_SECRET_NAME']
    bucket_name = os.environ['S3_BUCKET_NAME']
    region_name = os.environ['AWS_REGION']

    # Recupera las credenciales de la base de datos desde AWS Secrets Manager
    client = boto3.client('secretsmanager', region_name=region_name)
    secret = json.loads(client.get_secret_value(SecretId=secret_name)['SecretString'])

    # Conecta a la base de datos RDS PostgreSQL
    conn = psycopg2.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret.get('port', 5432),
        connect_timeout=5
    )
    cursor = conn.cursor()
    
    # Consulta todas las películas registradas en la cartelera
    cursor.execute("SELECT id, title, poster_key FROM movies;")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    
    # Inicializa el cliente S3 configurando explícitamente signature_version='s3v4' requerido por el cifrado KMS del bucket
    s3_client = boto3.client('s3', region_name=region_name, config=Config(signature_version='s3v4'))
    
    movies = []
    for r in rows:
        # Genera una URL prefirmada temporal y segura de S3 para acceder al póster de cada película que expira en 1 hora
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': r[2]},
            ExpiresIn=3600
        )
        movies.append({"id": r[0], "title": r[1], "poster_url": presigned_url})

    return {"statusCode": 200, "body": json.dumps(movies)}
