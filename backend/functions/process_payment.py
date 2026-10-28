import os
import boto3
import json
import psycopg2

table = boto3.resource('dynamodb').Table(os.environ['DYNAMODB_TABLE_NAME'])

def lambda_handler(event, context):
    try:
        # 1. Extraer usuario autenticado del JWT
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        user_id = claims.get('email') or claims.get('username') or claims.get('sub')

        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else (event.get('body') or {})
        showtime_id = body.get('showtime_id') or body.get('show_id')
        seat_id = body.get('seat_id')
        idempotency_key = body.get('idempotency_key')

        if not showtime_id or not seat_id:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Faltan showtime_id y seat_id para identificar la reserva a pagar."})
            }

        if not idempotency_key:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Falta la llave de idempotencia (idempotency_key)."})
            }

        # 2. Consultar la reserva en DynamoDB
        resp = table.get_item(Key={'showtime_id': str(showtime_id), 'seat_id': str(seat_id)})
        item = resp.get('Item')

        if not item:
            return {
                "statusCode": 404,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": f"No existe ninguna reserva para el asiento '{seat_id}' en la función '{showtime_id}'."})
            }

        # 3. Validar que quien paga sea el dueño de la reserva
        if user_id and item.get('user_id') and item.get('user_id') != user_id:
            return {
                "statusCode": 403,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "No puedes pagar una reserva perteneciente a otro usuario."})
            }

        # 4. Si ya estaba pagado, responder de inmediato
        if item.get('status') == 'PAID':
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "message": "Este asiento ya se encuentra pagado y confirmado.",
                    "showtime_id": str(showtime_id),
                    "seat_id": str(seat_id),
                    "movie": item.get('movie_title'),
                    "status": "PAID"
                })
            }

        # Obtiene el monto real asociado a la reserva
        amount = float(item.get('amount', 15.00))

        # 5. Registrar el pago en PostgreSQL con control de idempotencia
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
        
        try:
            cursor.execute(
                "INSERT INTO payments (idempotency_key, amount, status) VALUES (%s, %s, %s) ON CONFLICT (idempotency_key) DO NOTHING;",
                (idempotency_key, amount, 'SUCCESS')
            )
            conn.commit()
        except Exception as e:
            conn.rollback()
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": str(e)})
            }
        finally:
            cursor.close()
            conn.close()

        # 6. Actualizar el estado del asiento en DynamoDB a PAID (Confirmado)
        table.update_item(
            Key={'showtime_id': str(showtime_id), 'seat_id': str(seat_id)},
            UpdateExpression="SET #st = :paid, payment_id = :pid",
            ExpressionAttributeNames={'#st': 'status'},
            ExpressionAttributeValues={':paid': 'PAID', ':pid': idempotency_key}
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Pago procesado y reserva confirmada exitosamente.",
                "showtime_id": str(showtime_id),
                "seat_id": str(seat_id),
                "movie": item.get('movie_title'),
                "amount_paid": amount,
                "user": item.get('user_id'),
                "status": "PAID",
                "idempotency_key": idempotency_key
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Error procesando pago: {str(e)}"})
        }
