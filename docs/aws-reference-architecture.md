# AWS reference architecture

This document maps the locally verified pipeline to managed AWS services. The Docker deployment remains the reproducible implementation and source of every performance number in the main README; this design is an explicit migration target, not a claim that the complete managed stack has been benchmarked.

## Service mapping

| Verified implementation | AWS production target | Decision |
|---|---|---|
| Three Kafka brokers | Amazon MSK Serverless | Retains Kafka APIs while removing broker capacity management |
| Spark worker | EMR Serverless Spark | Workload-level isolation and pay-per-use execution |
| Three-node Cassandra | Amazon Keyspaces | Cassandra-compatible API without node operations |
| PostgreSQL primary/replica | Amazon Aurora PostgreSQL | Multi-AZ managed failover and reader endpoint |
| Local checkpoints | Versioned, encrypted Amazon S3 | Durable replay state independent of compute |
| Container logs | CloudWatch Logs and alarms | Centralized operational visibility |

## Network and security boundaries

```text
VPC 10.42.0.0/16
├── private subnet /24 (AZ-a)
│   ├── application compute
│   └── MSK Serverless endpoint
└── private subnet /24 (AZ-b)
    ├── application compute
    └── MSK Serverless endpoint
```

- MSK has no public endpoint and spans two Availability Zones.
- Kafka clients authenticate using IAM SASL rather than static passwords.
- The security group permits port 9098 only from members of the same application security group.
- S3 checkpoint storage blocks public access, uses server-side encryption and versioning, and remains independent of ephemeral compute.
- Production application roles should be separated into producer, consumer, and operations roles with topic- and bucket-scoped IAM policies.

## Reliability model

The local deployment proves one-broker and one-Cassandra-node tolerance. In AWS, MSK Serverless and managed databases transfer infrastructure failover to the service, while Spark checkpoints in S3 preserve consumer progress. Application-level idempotency remains required because Kafka-to-sink delivery is at least once.

## Cost tradeoffs

MSK Serverless is appropriate for variable Kafka workloads but has a non-zero baseline and can be more expensive than Kinesis for a fully AWS-native application. EMR Serverless avoids an always-on Spark cluster but should use execution timeouts and maximum-capacity controls. Development environments should be destroyed after testing; `terraform plan` is safe, while `terraform apply` creates billable resources.

## Provision the network and streaming foundation

```bash
terraform -chdir=infrastructure/aws init
terraform -chdir=infrastructure/aws plan
terraform -chdir=infrastructure/aws apply
```

The included Terraform provisions the two-AZ VPC boundary, private MSK Serverless cluster with IAM authentication, encrypted/versioned checkpoint bucket, and CloudWatch log group. EMR, Aurora, and Keyspaces are documented targets and intentionally excluded until workload sizing and a cost review are completed.
