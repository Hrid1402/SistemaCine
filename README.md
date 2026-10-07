# CinemaSpot

## Arquitectura en AWS
Se utilizará diferentes servicios de AWS para garantizar disponibilidad, escalabilidad y seguridad.

### Servicios utilizados
- **Amazon Route 53:** gestión del dominio y direccionamiento de usuarios.
- **AWS WAF:** protección de la aplicación frente a tráfico malicioso.
- **Amazon CloudFront:** distribución rápida del contenido mediante CDN.
- **Amazon S3:** almacenamiento de contenido estático como imágenes, posters y archivos web.
- **Amazon API Gateway:** comunicación entre el cliente y los servicios del sistema.
- **Amazon Cognito:** autenticación y gestión de usuarios.
- **AWS Lambda:** procesamiento de operaciones del sistema.
  - Consultar cartelera.
  - Reservar asiento.
- **Amazon DynamoDB:** almacenamiento de información que requiere consultas rápidas.
- **Amazon SQS:** gestión de tareas y operaciones de manera asíncrona.
- **Amazon RDS Proxy:** administración de conexiones hacia la base de datos.
- **Amazon RDS:** almacenamiento de información estructurada como usuarios, películas, funciones, reservas y pagos.
- **AWS Backup:** respaldo de las bases de datos.
- **Amazon QuickSight:** visualización de información y generación de reportes.
- **Amazon SNS:** envío de notificaciones a los clientes.

