import os
import boto3
import json
from decimal import Decimal
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_NAME'])
sqs_client = boto3.client('sqs')

FALLBACK_CATALOG = {
    "1": {"title": "Oppenheimer", "price": 15.00, "room": "Sala 1 - 2D", "total_seats": 300},
    "2": {"title": "La Red Social", "price": 12.50, "room": "Sala 2 - 2D", "total_seats": 300}
}

def parse_and_validate_seat_matrix(body):
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
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        user_id = claims.get('email') or claims.get('username') or claims.get('sub')

        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else (event.get('body') or {})

        if not user_id:
            user_id = body.get('user_id', 'guest_user')

        showtime_id = body.get('showtime_id') or body.get('show_id')
        if not showtime_id:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Falta el parámetro showtime_id en la solicitud."})
            }

        fila, columna, seat_id, seat_error = parse_and_validate_seat_matrix(body)
        if seat_error:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": seat_error})
            }

        movie_info = FALLBACK_CATALOG.get(str(showtime_id), {
            "title": body.get("movie_title", f"Función #{showtime_id}"),
            "price": float(body.get("price", 15.00)),
            "room": body.get("room", "Sala 1 - 2D"),
            "total_seats": 300
        })

        title = movie_info["title"]
        price = movie_info["price"]
        room = movie_info["room"]

        # Bloqueo atómico del asiento en DynamoDB
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

        # Enviar pedido a la Cola de compras en SQS si el cliente incluye idempotency_key
        sqs_queue_url = os.environ.get('SQS_QUEUE_URL')
        if sqs_queue_url and body.get('idempotency_key'):
            sqs_client.send_message(
                QueueUrl=sqs_queue_url,
                MessageBody=json.dumps({
                    "showtime_id": str(showtime_id),
                    "seat_id": str(seat_id),
                    "user_id": user_id,
                    "idempotency_key": body.get('idempotency_key')
                })
            )

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