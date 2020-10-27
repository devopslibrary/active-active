# Multi-region deployment.  These 2 regions have lowest cross region latency.
# 23-26ms per https://www.concurrencylabs.com/blog/choose-your-aws-region-wisely/

# Virginia (us-east-1)
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

# Ohio (us-east-2)
provider "aws" {
  alias  = "ohio"
  region = "us-east-2"
}