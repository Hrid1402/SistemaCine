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
