# VPC Input Variables

# VPC Name
variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "sr-labs-vpc"
}

# VPC CIDR Block
variable "vpc_cidr_block" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

# VPC Availability Zones
variable "vpc_availability_zones" {
  description = "Optional list of VPC Availability Zones. If empty, the first 3 available AZs in the region are used"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.vpc_availability_zones) == 0 || length(var.vpc_availability_zones) == 3
    error_message = "vpc_availability_zones must be empty (auto-detect) or contain exactly 3 AZs."
  }
}

# VPC Public Subnets
variable "vpc_public_subnets" {
  description = "VPC Public Subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  validation {
    condition     = length(var.vpc_public_subnets) == 3
    error_message = "vpc_public_subnets must contain exactly 3 CIDR blocks."
  }
}

# VPC Private Subnets
variable "vpc_private_subnets" {
  description = "VPC Private Subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  validation {
    condition     = length(var.vpc_private_subnets) == 3
    error_message = "vpc_private_subnets must contain exactly 3 CIDR blocks."
  }
}

# VPC Database Subnets
variable "vpc_database_subnets" {
  description = "VPC Database Subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.151.0/24", "10.0.152.0/24", "10.0.153.0/24"]
  validation {
    condition     = length(var.vpc_database_subnets) == 3
    error_message = "vpc_database_subnets must contain exactly 3 CIDR blocks."
  }
}

# VPC Create Database Subnet Group (True / False)
variable "vpc_create_database_subnet_group" {
  description = "VPC Create Database Subnet Group"
  type        = bool
  default     = true
}

# VPC Create Database Subnet Route Table (True or False)
variable "vpc_create_database_subnet_route_table" {
  description = "VPC Create Database Subnet Route Table"
  type        = bool
  default     = true
}


# VPC Enable NAT Gateway (True or False) 
variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateways for Private Subnets Outbound Communication"
  type        = bool
  default     = true
}

# VPC Single NAT Gateway (True or False)
variable "vpc_single_nat_gateway" {
  description = "Enable only single NAT Gateway in one Availability Zone to save costs during our demos"
  type        = bool
  default     = true
}





