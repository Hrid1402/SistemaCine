# CinemaSpot

## Arquitectura en AWS

El sistema utiliza servicios de AWS diseñados para garantizar alta disponibilidad, seguridad bajo el principio de mínimo privilegio y un rendimiento óptimo, se consideró para el PMV:

* **Amazon S3**: Almacenamiento privado de contenido estático (pósters e imágenes de películas).
* **Amazon API Gateway**: Puerta de entrada HTTP y enrutamiento hacia las funciones Lambda.
* **Amazon Cognito**: Autenticación de usuarios y emisión de tokens JWT (60 minutos de expiración).
* **AWS Lambda**: Procesamiento serverless para la lógica de negocio (cartelera, reservas y pagos).
* **Amazon DynamoDB**: Almacenamiento NoSQL rápido para el control y bloqueo de asientos.
* **Amazon RDS (PostgreSQL)**: Base de datos relacional para películas, funciones y registro de pagos.
* **AWS KMS & Secrets Manager**: Cifrado de datos en reposo y gestión segura de credenciales.
* **Amazon CloudWatch**: Monitoreo con métricas, grupos de logs, alarmas y dashboard centralizado.
* **AWS Identity and Access Management (IAM)**: Roles y políticas de mínimo privilegio.

## Endpoints de la API

| Método | Ruta | Acceso | Descripción |
| :--- | :--- | :--- | :--- |
| `GET` | `/cartelera` | Público | Consulta películas, salas, precios y asientos disponibles en tiempo real. |
| `POST` | `/reservar` | Protegido (JWT) | Reserva atómicamente un asiento en DynamoDB para el usuario autenticado. |
| `POST` | `/pagar` | Protegido (JWT) | Procesa el pago con idempotencia en PostgreSQL y confirma la reserva. |

> **Autenticación:** Las rutas protegidas se validan mediante un **JWT Authorizer** nativo en API Gateway conectado al User Pool de **Amazon Cognito**. Los usuarios inician sesión directamente contra Cognito y envían su token en la cabecera `Authorization: Bearer <token>`.
