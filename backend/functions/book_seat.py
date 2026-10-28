import os
import boto3
import json
import psycopg2
from decimal import Decimal
from botocore.exceptions import ClientError

table = boto3.resource('dynamodb').Table(os.environ['DYNAMODB_TABLE_NAME'])

def parse_and_validate_seat(seat_str):
    """Valida y normaliza el asiento. Para salas de 30 asientos: filas A, B, C de 10 sillas cada una."""
    cleaned = str(seat_str).strip().upper().replace(' ', '')
    if '-' in cleaned:
        parts = cleaned.split('-')
        row, num_str = parts[0], parts[1]
    elif len(cleaned) >= 2 and cleaned[0].isalpha() and cleaned[1:].isdigit():
        row, num_str = cleaned[0], cleaned[1:]
    else:
        return None, "Formato de asiento inválido. Usa formato Fila-Número (ejemplo: 'A-1', 'B-5', 'C-10')."

    valid_rows = ['A', 'B', 'C']
    if row not in valid_rows:
        return None, f"Fila '{row}' no válida. Las filas disponibles en esta sala son: {', '.join(valid_rows)}."

    try:
        num = int(num_str)
        if num < 1 or num > 10:
            return None, f"Número de silla '{num}' fuera de rango. En la fila {row} los asientos van del 1 al 10."
    except ValueError:
        return None, "El número de asiento debe ser numérico."

    return f"{row}-{num}", None

def lambda_handler(event, context):
    try:
        # 1. Extraer el usuario autenticado directamente del token JWT de Cognito
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        user_id = claims.get('email') or claims.get('username') or claims.get('sub')

        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else (event.get('body') or {})
        if not user_id:
            user_id = body.get('user_id') # Fallback para pruebas sin authorizer

        showtime_id = body.get('showtime_id') or body.get('show_id')
        raw_seat_id = body.get('seat_id')

        if not showtime_id or not raw_seat_id:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Faltan showtime_id y seat_id obligatorios en la solicitud."})
            }

        # 2. Validar estructura del asiento (Filas A, B, C con números 1 a 10)
        seat_id, seat_error = parse_and_validate_seat(raw_seat_id)
        if seat_error:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": seat_error})
            }

        # 3. Validar contra la base de datos RDS que la película / función realmente exista
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

        # 4. Bloqueo atómico del asiento en DynamoDB usando Decimal para campos numéricos
        seat_key = f"{showtime_id}#{seat_id}"
        try:
            table.put_item(
                Item={
                    'showtime_id': str(showtime_id),
                    'seat_id': str(seat_id),
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
                    "body": json.dumps({"error": f"El asiento '{seat_id}' ya se encuentra reservado por otro usuario."})
                }
            raise e

        return {
            "statusCode": 201,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": f"Asiento {seat_id} reservado con éxito. Estado: Pendiente de pago.",
                "showtime_id": str(showtime_id),
                "seat_id": str(seat_id),
                "movie": title,
                "room": room,
                "amount_to_pay": float(price),
                "user": user_id,
                "status": "PENDING_PAYMENT"
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Error reservando asiento: {str(e)}"})
        }
