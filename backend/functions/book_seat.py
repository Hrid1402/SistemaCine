import os
import boto3
import json
from botocore.exceptions import ClientError

# Crea la referencia a la tabla DynamoDB utilizando el nombre que nos dio la variable de entorno
table = boto3.resource('dynamodb').Table(os.environ['DYNAMODB_TABLE_NAME'])

def lambda_handler(event, context):
    # Extrae el cuerpo de la solicitud HTTP (JSON) que contiene los datos de la reserva
    body = json.loads(event.get('body', '{}'))
    show_id = body.get('show_id')
    seat_id = body.get('seat_id')
    user_id = body.get('user_id')

    # Construye una clave única compuesta combinando la función y el asiento
    seat_key = f"{show_id}#{seat_id}"

    try:
        # Realiza una escritura condicional atómica en DynamoDB para que no se pueda reservar el mismo asiento por dos usuarios al mismo tiempo
        table.put_item(
            Item={
                'seat_key': seat_key,
                'show_id': show_id,
                'seat_id': seat_id,
                'user_id': user_id,
                'status': 'RESERVED'
            },
            ConditionExpression='attribute_not_exists(seat_key)'
        )
    except ClientError as e:
        # Captura el error específico cuando la condición falla (el asiento ya existe en la tabla)
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return {"statusCode": 409, "body": json.dumps({"error": "Asiento ya reservado por otro usuario."})}
        raise e

    return {"statusCode": 201, "body": json.dumps({"message": "Asiento reservado con éxito."})}