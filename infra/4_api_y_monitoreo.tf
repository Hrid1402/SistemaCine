# 1. Directorio de usuarios de CinemaSpot.
resource "aws_cognito_user_pool" "cine_users" {
  name                     = "${var.project_name}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  tags = {
    Name = "${var.project_name}-users"
  }
}

# 2. Cliente publico (sin secreto) para autenticar usuarios desde Postman.
# El access token y el ID token caducan despues de 60 minutos.
resource "aws_cognito_user_pool_client" "cine_app" {
  name         = "${var.project_name}-app"
  user_pool_id = aws_cognito_user_pool.cine_users.id

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# 3. API HTTP (API Gateway v2).
resource "aws_apigatewayv2_api" "cine_api" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"
}

# 4. Verificacion JWT de Cognito: emisor y app client permitidos.
resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.cine_api.id
  name             = "${var.project_name}-cognito-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.cine_app.id]
    issuer   = "https://${aws_cognito_user_pool.cine_users.endpoint}"
  }
}

# 5. Publicacion automatica en la etapa default.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.cine_api.id
  name        = "$default"
  auto_deploy = true
}

# 6. Integraciones Lambda (proxy con payload HTTP API 2.0).
resource "aws_apigatewayv2_integration" "cartelera" {
  api_id                 = aws_apigatewayv2_api.cine_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_billboard.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "reservar" {
  api_id                 = aws_apigatewayv2_api.cine_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.book_seat.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "pagar" {
  api_id                 = aws_apigatewayv2_api.cine_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.process_payment.invoke_arn
  payload_format_version = "2.0"
}

# 7. Tres rutas protegidas por el mismo authorizer JWT.
resource "aws_apigatewayv2_route" "cartelera" {
  api_id               = aws_apigatewayv2_api.cine_api.id
  route_key            = "GET /cartelera"
  target               = "integrations/${aws_apigatewayv2_integration.cartelera.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_apigatewayv2_route" "reservar" {
  api_id               = aws_apigatewayv2_api.cine_api.id
  route_key            = "POST /reservar"
  target               = "integrations/${aws_apigatewayv2_integration.reservar.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_apigatewayv2_route" "pagar" {
  api_id               = aws_apigatewayv2_api.cine_api.id
  route_key            = "POST /pagar"
  target               = "integrations/${aws_apigatewayv2_integration.pagar.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

# 8. Permisos para que esta API invoque cada Lambda en su ruta.
resource "aws_lambda_permission" "api_cartelera" {
  statement_id  = "AllowCinemaApiCartelera"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_billboard.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.cine_api.execution_arn}/*/GET/cartelera"
}

resource "aws_lambda_permission" "api_reservar" {
  statement_id  = "AllowCinemaApiReservar"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.book_seat.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.cine_api.execution_arn}/*/POST/reservar"
}

resource "aws_lambda_permission" "api_pagar" {
  statement_id  = "AllowCinemaApiPagar"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_payment.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.cine_api.execution_arn}/*/POST/pagar"
}

# 9. Grupos de logs de las funciones Lambda (retencion de 14 dias).
resource "aws_cloudwatch_log_group" "cartelera" {
  name              = "/aws/lambda/${aws_lambda_function.get_billboard.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "reservar" {
  name              = "/aws/lambda/${aws_lambda_function.book_seat.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "pagar" {
  name              = "/aws/lambda/${aws_lambda_function.process_payment.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "init_db" {
  name              = "/aws/lambda/${aws_lambda_function.init_db.function_name}"
  retention_in_days = 14
}

# 10. Una alarma cuando las 3 Lambdas de la API acumulen 1 o mas errores en 5 minutos.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  alarm_description   = "Errores acumulados en las Lambdas de cartelera, reserva y pago"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "total"
    expression  = "SUM(METRICS())"
    label       = "Errores totales de las 3 Lambdas"
    return_data = true
  }

  metric_query {
    id          = "cartelera"
    return_data = false
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = aws_lambda_function.get_billboard.function_name
      }
    }
  }

  metric_query {
    id          = "reservar"
    return_data = false
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = aws_lambda_function.book_seat.function_name
      }
    }
  }

  metric_query {
    id          = "pagar"
    return_data = false
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = aws_lambda_function.process_payment.function_name
      }
    }
  }
}

# 11. Dashboard con 2 graficas: invocaciones y errores por funcion Lambda.
resource "aws_cloudwatch_dashboard" "cine_dashboard" {
  dashboard_name = "${var.project_name}-lambda-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Invocaciones Lambda"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 300
          stat    = "Sum"
          stacked = false
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.get_billboard.function_name, { label = "Cartelera" }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.book_seat.function_name, { label = "Reservar" }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.process_payment.function_name, { label = "Pagar" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Errores Lambda"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 300
          stat    = "Sum"
          stacked = false
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.get_billboard.function_name, { label = "Cartelera" }],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.book_seat.function_name, { label = "Reservar" }],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.process_payment.function_name, { label = "Pagar" }]
          ]
        }
      }
    ]
  })
}

# 12. Outputs para consultar valores de AWS y configurar Postman.
output "api_gateway_url" {
  description = "URL base del HTTP API de CinemaSpot"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito"
  value       = aws_cognito_user_pool.cine_users.id
}

output "cognito_app_client_id" {
  description = "ID del App Client para autenticar usuarios desde Postman"
  value       = aws_cognito_user_pool_client.cine_app.id
}

output "cognito_region" {
  description = "Region del User Pool de Cognito"
  value       = var.aws_region
}