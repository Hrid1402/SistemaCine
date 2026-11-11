import os
import boto3
import json
import psycopg2
from decimal import Decimal
from botocore.exceptions import ClientError

table = boto3.resource('dynamodb').Table(os.environ['DYNAMODB_TABLE_NAME'])

def parse_and_validate_seat_matrix(body):
    """
    Valida y extrae fila y columna para la matriz de 15x20.
    Espera recibir {"fila": X, "columna": Y} en el body.
    """
    try:
        fila = int(body.get('fila'))
        columna = int(body.get('columna'))
    except (TypeError, ValueError):
        return None, None, None, "Los campos 'fila' y 'columna' son obligatorios y deben ser numéricos."

    if fila < 1 or fila > 15:
        return None, None, None, f"Fila '{fila}' fuera de rango. Las filas disponibles van del 1 al 15."

    if columna < 1 or columna > 20:
        return None, None, None, f"Columna '{columna}' fuera de rango. Las columnas van del 1 al 20."

    row_letter = chr(64 + fila)
    seat_id = f"{row_letter}-{columna}"
    return fila, columna, seat_id, None

def lambda_handler(event, context):
    try:
        # 1. Extraer el usuario autenticado del token JWT de Cognito
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        user_id = claims.get('email') or claims.get('username') or claims.get('sub')

        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else (event.get('body') or {})
        if not user_id:
            user_id = body.get('user_id') # Fallback para pruebas sin authorizer

        showtime_id = body.get('showtime_id') or body.get('show_id')

        if not showtime_id:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Falta el parámetro showtime_id en la solicitud."})
            }

        # 2. Validar coordenadas de la matriz (15x20)
        fila, columna, seat_id, seat_error = parse_and_validate_seat_matrix(body)
        if seat_error:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": seat_error})
            }

        # 3. Validar contra la base de datos RDS que la función exista
        secret_name = os.environ['DB_SECRET_NAME']
        region_name = os.environ.get('AWS_REGION', 'sa-east-1')
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
        cursor.execute("SELECT title, price, room, total_seats FROM movies WHERE id = %s;", (showtime_id,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()

        if not row:
            return {
                "statusCode": 404,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": f"La función con ID '{showtime_id}' no existe en la cartelera."})
            }

        title, price, room, total_seats = row[0], row[1], row[2], int(row[3])

        # 4. Bloqueo atómico del asiento en DynamoDB
        seat_key = f"{showtime_id}#F{fila}C{columna}"
        try:
            table.put_item(
                Item={
                    'showtime_id': str(showtime_id),
                    'seat_id': str(seat_id),
                    'fila': Decimal(str(fila)),
                    'columna': Decimal(str(columna)),
                    'show_id': str(showtime_id),
                    'seat_key': seat_key,
                    'user_id': user_id,
                    'movie_title': title,
                    'amount': Decimal(str(price)),
                    'status': 'PENDING_PAYMENT'
                },
                ConditionExpression='attribute_not_exists(showtime_id) AND attribute_not_exists(seat_id)'
            )
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                return {
                    "statusCode": 409,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": f"El asiento en la fila {fila}, columna {columna} ({seat_id}) ya se encuentra reservado."})
                }
            raise e

        return {
            "statusCode": 201,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": f"Asiento {seat_id} reservado con éxito.",
                "showtime_id": str(showtime_id),
                "seat": {
                    "fila": fila,
                    "columna": columna,
                    "nombre": seat_id,
                    "estado": "PENDING_PAYMENT"
                },
                "movie": title,
                "room": room,
                "amount_to_pay": float(price),
                "user": user_id,
                "status": "PENDING_PAYMENT"
            }, default=str)
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Error reservando asiento: {str(e)}"})
        }