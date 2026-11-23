import os
import boto3
import json
import psycopg2
from boto3.dynamodb.conditions import Key
from botocore.client import Config

dynamodb = boto3.resource('dynamodb')

# Caché de respaldo en caso de caída
FALLBACK_MOVIES = [
    (1, 'Oppenheimer', 'posters/poster_oppenheimer.jpg', 15.00, 'Sala 1 - 2D', 300),
    (2, 'La Red Social', 'posters/poster_la_red_social.png', 12.50, 'Sala 2 - 2D', 300)
]

def lambda_handler(event, context):
    try:
        secret_name = os.environ['DB_SECRET_NAME']
        bucket_name = os.environ['S3_BUCKET_NAME']
        region_name = os.environ['AWS_REGION']
        table_name = os.environ['DYNAMODB_TABLE_NAME']
        cloudfront_domain = os.environ.get('CLOUDFRONT_DOMAIN')

        rows = None
        try:
            client = boto3.client('secretsmanager', region_name=region_name)
            secret = json.loads(client.get_secret_value(SecretId=secret_name)['SecretString'])

            conn = psycopg2.connect(
                host=secret['host'],
                database=secret['dbname'],
                user=secret['username'],
                password=secret['password'],
                port=secret.get('port', 5432),
                connect_timeout=3
            )
            cursor = conn.cursor()
            cursor.execute("SELECT id, title, poster_key, price, room, total_seats FROM movies;")
            rows = cursor.fetchall()
            cursor.close()
            conn.close()
        except Exception:
            # Fallback automático a caché si RDS no disponible
            rows = FALLBACK_MOVIES

        s3_client = boto3.client(
            's3',
            region_name=region_name,
            endpoint_url=f"https://s3.{region_name}.amazonaws.com",
            config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'})
        )

        table = dynamodb.Table(table_name)
        movies = []

        for r in rows:
            showtime_id_str = str(r[0])
            resp = table.query(KeyConditionExpression=Key('showtime_id').eq(showtime_id_str))
            items = resp.get('Items', [])

            seats_status_map = {}
            for item in items:
                f = int(item.get('fila', 0))
                c = int(item.get('columna', 0))
                seats_status_map[(f, c)] = item.get('status', 'OCUPADO')

            room_matrix = []
            total_seats = int(r[5]) if r[5] else 300
            occupied_count = 0

            for r_idx in range(1, 16):
                row_seats = []
                row_letter = chr(64 + r_idx)
                for c_idx in range(1, 21):
                    status = "DISPONIBLE"
                    if (r_idx, c_idx) in seats_status_map:
                        status = seats_status_map[(r_idx, c_idx)]
                        occupied_count += 1

                    row_seats.append({
                        "fila": r_idx,
                        "columna": c_idx,
                        "nombre": f"{row_letter}-{c_idx}",
                        "estado": status
                    })
                room_matrix.append(row_seats)

            available_seats = max(0, total_seats - occupied_count)
            is_full = available_seats == 0

            if cloudfront_domain:
                poster_url = f"https://{cloudfront_domain}/{r[2]}"
            else:
                poster_url = s3_client.generate_presigned_url(
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
                "room_layout": "Matriz 15x20 (Filas 1-15, Columnas 1-20)",
                "room_matrix": room_matrix,
                "poster_url": poster_url
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