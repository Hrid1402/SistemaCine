import os
import boto3
import json
from botocore.exceptions import ClientError

# Crea la referencia a la tabla DynamoDB utilizando el nombre que nos dio la variable de entorno
table = boto3.resource('dynamodb').Table(os.environ['DYNAMODB_TABLE_NAME'])

def lambda_handler(event, context):
    # Extrae el cuerpo de la solicitud HTTP (JSON) que contiene los datos de la reserva
    body = json.loads(event.get('body', '{}'))
    showtime_id = body.get('showtime_id') or body.get('show_id')
    seat_id = body.get('seat_id')
    user_id = body.get('user_id')

    if not showtime_id or not seat_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Faltan showtime_id (o show_id) y seat_id obligatorios."})
        }

    # Construye una clave única compuesta combinando la función y el asiento
    seat_key = f"{showtime_id}#{seat_id}"

    try:
        # Realiza una escritura condicional atómica en DynamoDB usando la clave primaria (showtime_id, seat_id)
        table.put_item(
            Item={
                'showtime_id': showtime_id,
                'seat_id': seat_id,
                'show_id': showtime_id,
                'seat_key': seat_key,
                'user_id': user_id,
                'status': 'RESERVED'
            },
            ConditionExpression='attribute_not_exists(showtime_id) AND attribute_not_exists(seat_id)'
        )
    except ClientError as e:
        # Captura el error específico cuando la condición falla (el asiento ya existe en la tabla)
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return {"statusCode": 409, "body": json.dumps({"error": "Asiento ya reservado por otro usuario."})}
        raise e

    return {"statusCode": 201, "body": json.dumps({"message": "Asiento reservado con éxito."})}
