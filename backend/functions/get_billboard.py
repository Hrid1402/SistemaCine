import os
import boto3
import json
import psycopg2
from boto3.dynamodb.conditions import Key
from botocore.client import Config

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    try:
        secret_name = os.environ['DB_SECRET_NAME']
        bucket_name = os.environ['S3_BUCKET_NAME']
        region_name = os.environ.get('AWS_REGION', 'sa-east-1')
        table_name = os.environ['DYNAMODB_TABLE_NAME']

        # Recupera credenciales desde AWS Secrets Manager
        client = boto3.client('secretsmanager', region_name=region_name)
        secret = json.loads(client.get_secret_value(SecretId=secret_name)['SecretString'])

        conn = psycopg2.connect(
            host=secret['host'],
            database=secret['dbname'],
            user=secret['username'],
            password=secret['password'],
            port=secret.get('port', 5432),
            connect_timeout=5
        )
        cursor = conn.cursor()
        
        # Consulta películas con su información de sala, precio y capacidad
        cursor.execute("SELECT id, title, poster_key, price, room, total_seats FROM movies;")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        
        s3_client = boto3.client('s3', region_name=region_name, config=Config(signature_version='s3v4'))
        table = dynamodb.Table(table_name)
        
        movies = []
        for r in rows:
            showtime_id_str = str(r[0])
            total_seats = int(r[5])
            
            # Consultar en DynamoDB qué asientos ya están ocupados en esta función
            resp = table.query(KeyConditionExpression=Key('showtime_id').eq(showtime_id_str))
            occupied_seats = [item['seat_id'] for item in resp.get('Items', [])]
            available_seats = max(0, total_seats - len(occupied_seats))
            is_full = available_seats == 0

            presigned_url = s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': bucket_name, 'Key': r[2]},
                ExpiresIn=3600
            )

            movies.append({
                "showtime_id": showtime_id_str,
                "title": r[1],
                "room": r[4],
                "price": float(r[3]),
                "total_seats": total_seats,
                "available_seats": available_seats,
                "is_full": is_full,
                "room_layout": "Filas A, B, C (asientos del 1 al 10)",
                "occupied_seats": occupied_seats,
                "poster_url": presigned_url
            })

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(movies)
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Error en cartelera: {str(e)}"})
        }
