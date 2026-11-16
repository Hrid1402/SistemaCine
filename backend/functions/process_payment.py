import os
import boto3
import json
import psycopg2

table = boto3.resource('dynamodb').Table(os.environ['DYNAMODB_TABLE_NAME'])
sns_client = boto3.client('sns')

def process_single_payment(body, user_id=None):
    showtime_id = body.get('showtime_id') or body.get('show_id')
    seat_id = body.get('seat_id')
    idempotency_key = body.get('idempotency_key')

    if not showtime_id or not seat_id:
        return 400, {"error": "Faltan showtime_id y seat_id para identificar la reserva a pagar."}

    if not idempotency_key:
        return 400, {"error": "Falta la llave de idempotencia (idempotency_key)."}

    resp = table.get_item(Key={'showtime_id': str(showtime_id), 'seat_id': str(seat_id)})
    item = resp.get('Item')

    if not item:
        return 404, {"error": f"No existe ninguna reserva para el asiento '{seat_id}' en la función '{showtime_id}'."}

    if user_id and item.get('user_id') and item.get('user_id') != user_id:
        return 403, {"error": "No puedes pagar una reserva perteneciente a otro usuario."}

    if item.get('status') == 'PAID':
        return 200, {
            "message": "Este asiento ya se encuentra pagado y confirmado.",
            "showtime_id": str(showtime_id),
            "seat_id": str(seat_id),
            "movie": item.get('movie_title'),
            "status": "PAID"
        }

    amount = float(item.get('amount', 15.00))

    secret_name = os.environ['DB_SECRET_NAME']
    region_name = os.environ['AWS_REGION']
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

    try:
        cursor.execute(
            "INSERT INTO payments (idempotency_key, amount, status) VALUES (%s, %s, %s) ON CONFLICT (idempotency_key) DO NOTHING;",
            (idempotency_key, amount, 'SUCCESS')
        )
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()

    table.update_item(
        Key={'showtime_id': str(showtime_id), 'seat_id': str(seat_id)},
        UpdateExpression="SET #st = :paid, payment_id = :pid",
        ExpressionAttributeNames={'#st': 'status'},
        ExpressionAttributeValues={':paid': 'PAID', ':pid': idempotency_key}
    )

    result_payload = {
        "message": "Pago procesado y reserva confirmada exitosamente.",
        "showtime_id": str(showtime_id),
        "seat_id": str(seat_id),
        "movie": item.get('movie_title'),
        "amount_paid": amount,
        "user": item.get('user_id'),
        "status": "PAID",
        "idempotency_key": idempotency_key
    }

    # Publicar confirmación de entrada emitida en Amazon SNS
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if sns_topic_arn:
        try:
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject=f"Entrada Confirmada - {item.get('movie_title')}",
                Message=json.dumps(result_payload)
            )
        except Exception:
            pass

    return 200, result_payload

def lambda_handler(event, context):
    if 'Records' in event:
        for record in event['Records']:
            payload = json.loads(record['body'])
            status_code, response_body = process_single_payment(payload, payload.get('user_id'))
            if status_code >= 500:
                raise RuntimeError(response_body.get('error', 'Error en procesamiento SQS'))
        return {"statusCode": 200, "body": json.dumps({"message": "Lote SQS procesado"})}

    try:
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        user_id = claims.get('email') or claims.get('username') or claims.get('sub')
        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else (event.get('body') or {})

        status_code, response_body = process_single_payment(body, user_id)
        return {
            "statusCode": status_code,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(response_body)
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Error procesando pago: {str(e)}"})
        }