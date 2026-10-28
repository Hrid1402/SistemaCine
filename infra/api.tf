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

# 7. Cartelera publica; reserva y pago protegidos por Cognito JWT.
resource "aws_apigatewayv2_route" "cartelera" {
  api_id             = aws_apigatewayv2_api.cine_api.id
  route_key          = "GET /cartelera"
  target             = "integrations/${aws_apigatewayv2_integration.cartelera.id}"
  authorization_type = "NONE"
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
