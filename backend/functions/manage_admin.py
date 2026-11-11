import os
import boto3
import json
import psycopg2
from datetime import datetime, timedelta

def get_db_connection():
    """Recupera credenciales de AWS Secrets Manager y se conecta a PostgreSQL (RDS)."""
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
    return conn

def create_room(conn, body):
    """Crea una nueva sala de cine con número de filas y columnas."""
    name = body.get('name')
    total_rows = body.get('total_rows', 15)
    total_columns = body.get('total_columns', 20)

    if not name:
        return {"statusCode": 400, "body": json.dumps({"error": "El nombre de la sala es obligatorio."})}

    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO rooms (name, total_rows, total_columns) VALUES (%s, %s, %s) RETURNING id;",
            (name, total_rows, total_columns)
        )
        room_id = cursor.fetchone()[0]
        conn.commit()
        return {
            "statusCode": 201,
            "body": json.dumps({
                "message": f"Sala '{name}' creada con éxito.",
                "room_id": room_id,
                "capacity": total_rows * total_columns
            })
        }
    except psycopg2.IntegrityError:
        conn.rollback()
        return {"statusCode": 409, "body": json.dumps({"error": f"Ya existe una sala con el nombre '{name}'."})}
    finally:
        cursor.close()

def create_movie(conn, body):
    """Registra una nueva película en el catálogo."""
    title = body.get('title')
    poster_key = body.get('poster_key')
    duration_minutes = body.get('duration_minutes', 120)

    if not title or not poster_key:
        return {"statusCode": 400, "body": json.dumps({"error": "Faltan título o poster_key de la película."})}

    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO movies_catalog (title, poster_key, duration_minutes) VALUES (%s, %s, %s) RETURNING id;",
        (title, poster_key, duration_minutes)
    )
    movie_id = cursor.fetchone()[0]
    conn.commit()
    cursor.close()

    return {
        "statusCode": 201,
        "body": json.dumps({
            "message": f"Película '{title}' creada exitosamente.",
            "movie_id": movie_id,
            "duration_minutes": duration_minutes
        })
    }

def create_showtime(conn, body):
    """
    Programa una nueva función (Showtime) asegurando que NO exista cruce de horarios
    en la misma sala.
    """
    movie_id = body.get('movie_id')
    room_id = body.get('room_id')
    price = body.get('price', 15.00)
    start_time_str = body.get('start_time') # Formato esperado: "YYYY-MM-DD HH:MM:SS"

    if not movie_id or not room_id or not start_time_str:
        return {"statusCode": 400, "body": json.dumps({"error": "Faltan movie_id, room_id o start_time."})}

    try:
        start_time = datetime.strptime(start_time_str, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return {"statusCode": 400, "body": json.dumps({"error": "Formato de fecha inválido. Usa 'YYYY-MM-DD HH:MM:SS'."})}

    cursor = conn.cursor()

    # Obtener la duración de la película para calcular la hora de fin
    cursor.execute("SELECT duration_minutes, title FROM movies_catalog WHERE id = %s;", (movie_id,))
    movie_row = cursor.fetchone()
    if not movie_row:
        cursor.close()
        return {"statusCode": 404, "body": json.dumps({"error": f"La película con ID {movie_id} no existe."})}

    duration_minutes, movie_title = movie_row[0], movie_row[1]
    
    end_time = start_time + timedelta(minutes=duration_minutes + 15)

    # VALIDACIÓN DE SOLAPAMIENTO DE HORARIOS EN LA MISMA SALA
    cursor.execute("""
        SELECT id, start_time, end_time
        FROM showtimes
        WHERE room_id = %s
          AND (%s < end_time AND %s > start_time);
    """, (room_id, start_time, end_time))

    conflict = cursor.fetchone()
    if conflict:
        cursor.close()
        return {
            "statusCode": 409,
            "body": json.dumps({
                "error": f"Conflicto de horario: La sala ya tiene asignada una función en ese rango.",
                "conflicting_showtime_id": conflict[0],
                "occupied_from": str(conflict[1]),
                "occupied_until": str(conflict[2])
            })
        }

    # Insertar la función si no hay solapamiento
    cursor.execute("""
        INSERT INTO showtimes (movie_id, room_id, price, start_time, end_time)
        VALUES (%s, %s, %s, %s, %s) RETURNING id;
    """, (movie_id, room_id, price, start_time, end_time))
    
    showtime_id = cursor.fetchone()[0]
    conn.commit()
    cursor.close()

    return {
        "statusCode": 201,
        "body": json.dumps({
            "message": "Función programada exitosamente.",
            "showtime_id": showtime_id,
            "movie": movie_title,
            "room_id": room_id,
            "start_time": str(start_time),
            "end_time": str(end_time),
            "price": float(price)
        })
    }

def lambda_handler(event, context):
    try:
        # Validación de autenticación JWT / Cognito
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        user_id = claims.get('email') or claims.get('username') or claims.get('sub')
        
        cognito_groups = claims.get('cognito:groups', [])
        if 'Admin' not in cognito_groups and 'Admins' not in cognito_groups:
            return {"statusCode": 403, "body": json.dumps({"error": "No tienes permisos de administrador."})}

        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else (event.get('body') or {})
        action = body.get('action') # 'create_room', 'create_movie', 'create_showtime'

        conn = get_db_connection()

        if action == 'create_room':
            res = create_room(conn, body)
        elif action == 'create_movie':
            res = create_movie(conn, body)
        elif action == 'create_showtime':
            res = create_showtime(conn, body)
        else:
            res = {
                "statusCode": 400,
                "body": json.dumps({"error": "Acción inválida. Usa 'create_room', 'create_movie' o 'create_showtime'."})
            }

        conn.close()
        
        res["headers"] = {"Content-Type": "application/json"}
        return res

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": f"Error en la administración: {str(e)}"})
        }