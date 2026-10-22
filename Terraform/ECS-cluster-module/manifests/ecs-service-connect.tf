# ECS Service Connect namespace (AWS Cloud Map, HTTP namespace: no Route 53 private zone)
# The services of the cluster find each other by name through it, without going through the ALB.
# Example: the web service calls the api at http://api:4000 (the api is the Service Connect "server").
resource "aws_service_discovery_http_namespace" "this" {
  name        = local.service_connect_namespace
  description = "ECS Service Connect namespace of ${local.cluster_name}"
  tags        = local.common_tags
}
