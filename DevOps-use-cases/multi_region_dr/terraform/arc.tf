# AWS Route 53 Application Recovery Controller (ARC) Config

resource "aws_route53recoverycontrolconfig_cluster" "dr_cluster" {
  name = "usaa-banking-dr-cluster"
}

resource "aws_route53recoverycontrolconfig_control_panel" "dr_control_panel" {
  name        = "usaa-banking-core-panel"
  cluster_arn = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
}

resource "aws_route53recoverycontrolconfig_routing_control" "primary_switch" {
  name              = "us-east-1-primary-switch"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.dr_control_panel.arn
}

resource "aws_route53recoverycontrolconfig_routing_control" "dr_switch" {
  name              = "us-west-2-dr-switch"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.dr_control_panel.arn
}

# Route 53 DNS Entries & ARC Routing Control integration
data "aws_route53_zone" "banking" {
  name         = "banking.usaa.com."
  private_zone = true
}

# Health checks tracking the status of ARC routing control states
resource "aws_route53_health_check" "primary_arc_check" {
  type                            = "RECOVERY_CONTROL"
  routing_control_arn             = aws_route53recoverycontrolconfig_routing_control.primary_switch.arn
  insufficient_data_health_status = "LastKnownStatus"

  tags = {
    Name = "us-east-1-primary-arc-hc"
  }
}

resource "aws_route53_health_check" "dr_arc_check" {
  type                            = "RECOVERY_CONTROL"
  routing_control_arn             = aws_route53recoverycontrolconfig_routing_control.dr_switch.arn
  insufficient_data_health_status = "LastKnownStatus"

  tags = {
    Name = "us-west-2-dr-arc-hc"
  }
}

# DNS Records matching ARC Health Checks
resource "aws_route53_record" "primary_record" {
  zone_id         = data.aws_route53_zone.banking.zone_id
  name            = "core-api.banking.usaa.com"
  type            = "A"
  health_check_id = aws_route53_health_check.primary_arc_check.id

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "us-east-1-primary"

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dr_record" {
  zone_id         = data.aws_route53_zone.banking.zone_id
  name            = "core-api.banking.usaa.com"
  type            = "A"
  health_check_id = aws_route53_health_check.dr_arc_check.id

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "us-west-2-dr"

  alias {
    name                   = var.dr_alb_dns_name
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = true
  }
}
