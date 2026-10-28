import os
import boto3
import json
import psycopg2

def lambda_handler(event, context):
    # Parsea el cuerpo de la solicitud HTTP entrante
    body = json.loads(event.get('body', '{}'))
    idempotency_key = body.get('idempotency_key')
    amount = body.get('amount')

    # Valida que obligatoriamente se envíe la clave de idempotencia
    if not idempotency_key:
        return {"statusCode": 400, "body": "Falta la llave de idempotencia (idempotency_key)."}
    
    # Obtiene las credenciales cifradas de la base de datos RDS desde AWS Secrets Manager
    secret = json.loads(boto3.client('secretsmanager', region_name=os.environ['AWS_REGION']).get_secret_value(SecretId=os.environ['DB_SECRET_NAME'])['SecretString'])
    
    # Conecta a la base de datos relacional PostgreSQL en RDS
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
        # Inserta el pago aplicando control de idempotencia, si la misma solicitud de pago llega duplicada, no se procesa ni cobra dos veces
        cursor.execute(
            "INSERT INTO payments (idempotency_key, amount, status) VALUES (%s, %s, %s) ON CONFLICT (idempotency_key) DO NOTHING;",
            (idempotency_key, amount, 'SUCCESS')
        )
        conn.commit() # Confirma la transacción
    except Exception as e:
        conn.rollback() # Revierte los cambios ante cualquier error inesperado
        return {"statusCode": 500, "body": str(e)}
    finally:
        # Asegura el cierre de conexiones a la base de datos
        cursor.close()
        conn.close()

    return {"statusCode": 200, "body": json.dumps({"message": "Pago procesado exitosamente."})}
