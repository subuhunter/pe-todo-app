# Multi-AZ Web Architecture — Terraform

Per-environment Terraform for the AWS beginner-task architecture: a VPC with
public and private subnets across two AZs, two private web servers behind an
internet-facing Application Load Balancer, a bastion host, an S3 bucket for
logs and files, CloudWatch alarms, and IAM. Remote state lives in S3.

Only **dev** is built out; qa and production are stubs.

## Layout

```
terraform/
├── env/                      # One root module per environment
│   ├── dev/                  # ← the only one provisioned today
│   │   ├── backend.tf        # S3 state, key = ec2-demo/dev/...
│   │   ├── versions.tf       # Terraform + provider version pins
│   │   ├── providers.tf      # AWS provider, default_tags
│   │   ├── main.tf           # Calls every module and wires them together
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars  # Dev values (committed)
│   │   └── user_data/        # Instance bootstrap templates
│   │       ├── web.sh.tftpl      # httpd, CloudWatch agent, S3 upload
│   │       └── bastion.sh.tftpl  # minimal, SSM agent, motd
│   ├── qa/                   # README only
│   └── production/           # README only — includes a hardening checklist
├── bootstrap/                # Creates the shared S3 state bucket (local state)
└── modules/
    ├── network/              # VPC, subnets, IGW, NAT, route tables, S3 endpoint
    ├── alb/                  # ALB, target group, listener, ALB security group
    ├── ec2/                  # One instance + its security group (used 3×)
    ├── storage/              # Application S3 bucket
    ├── iam/                  # EC2 instance role/profile + admin user
    └── monitoring/           # Log group, SNS topic, CloudWatch alarms
```

Each environment is an **independent root module** with its own state file.
They share code but nothing at runtime, so a broken apply in dev cannot touch
production. Environments are separated by state **key**, not by bucket — one
bucket, three prefixes.

## Architecture

```
                        Internet
                            │
                    Internet Gateway
                            │
                 ┌──────────┴───────────┐
                 │   Application LB     │   public-a 10.0.1.0/24 (AZ a)
                 │   (2 AZs, port 80)   │   public-b 10.0.2.0/24 (AZ b)
                 └──────────┬───────────┘
                            │  target group, health check GET /health
              ┌─────────────┴─────────────┐
              ▼                           ▼
        ┌───────────┐               ┌───────────┐
        │  web-1    │               │  web-2    │   private-a 10.0.11.0/24
        │  httpd    │               │  httpd    │   private-b 10.0.12.0/24
        └─────┬─────┘               └─────┬─────┘   no public IP
              │      NAT GW (public-a)    │
              └──────────┬────────────────┘
                         │
              S3 gateway endpoint ──► S3 bucket (logs/, test/)
                         └──────────► CloudWatch logs + alarms

    Admin ──SSH:22──► bastion (public, 10.0.3.0/24) ──SSH:22──► web-1/web-2
    Admin ──SSM Session Manager──────────────────────────────► any instance
```

Ingress is chained by **security group reference**, never by CIDR:

| Target | Allows | From |
|--------|--------|------|
| ALB SG | :80 | `alb_ingress_cidrs` (0.0.0.0/0) |
| Web SG | :80 | the ALB's security group |
| Web SG | :22 | the bastion's security group |
| Bastion SG | :22 | `allowed_ssh_cidrs` (empty by default) |

## Step 1 — pick a bucket name

S3 bucket names are globally unique. This name goes in **two places** and must
match exactly:

1. `backend "s3" { bucket = ... }` in `env/dev/backend.tf`
2. `state_bucket_name` in `bootstrap/terraform.tfvars`

The duplication is unavoidable: Terraform evaluates the backend block before
variables exist, so it accepts only literals — no `var.`, no interpolation.
Same applies to `region`.

## Step 2 — create the state bucket (once per account)

```bash
cd terraform/bootstrap
export AWS_PROFILE=your-profile

cp terraform.tfvars.example terraform.tfvars   # then set state_bucket_name
terraform init
terraform apply
```

This creates the bucket with versioning, encryption, public access blocked, a
TLS-only bucket policy, and a lifecycle rule expiring superseded state
versions after 90 days. It serves all environments.

## Step 3 — deploy dev

```bash
cd terraform/env/dev
terraform init
terraform plan
terraform apply
```

`terraform.tfvars` is picked up automatically. Then:

```bash
terraform output website_url          # open it — allow ~2 min for health checks
terraform output ssm_session_commands # shell into a private web server
terraform output app_bucket_name      # boot reports under test/, logs under logs/
```

Tear down with `terraform destroy`.

## What the dev stack creates

**67 resources.** Counts below come from the committed `terraform.tfvars`:

```
VPC                          : 1
Public subnets               : 3   (public-a, public-b, bastion)
Private subnets              : 2   (private-a, private-b)
Internet gateways            : 1
NAT gateways (+ EIP)         : 1   (+1)
Route tables                 : 3   (1 public shared, 1 per private subnet)
Routes                       : 3
Route table associations     : 5
S3 gateway VPC endpoints     : 1
Application load balancers   : 1
Target groups                : 1
Listeners                    : 1
Target group attachments     : 2
EC2 instances                : 3   (web-1, web-2, bastion)
Security groups              : 4   (alb, web-1, web-2, bastion)
Security group rules         : 9   (see note below)
S3 buckets (application)     : 1   (+6 bucket configurations)
IAM roles / profiles         : 1 / 1
IAM role policies + attaches : 3
IAM users / policies         : 1 / 1 (+1 attachment)
CloudWatch log groups        : 1
CloudWatch alarms            : 8   (CPU ×3, status ×3, unhealthy hosts, ELB 5xx)
SNS topics                   : 1
```

Security group rule detail: 1 ALB ingress + 1 ALB egress, 2 ingress + 1 egress
per web server (×2), 0 ingress + 1 egress on the bastion (`allowed_ssh_cidrs`
is empty by default) = 9 rule resources.

## Cost

Roughly **$75–85/month** if left running in ap-south-1:

| Item | Approx. monthly |
|------|-----------------|
| NAT Gateway | $32 + $0.045/GB processed |
| Application Load Balancer | $16 + LCU charges |
| 3 × t3.micro | $24 |
| EBS (48 GiB gp3) | $4 |
| Elastic IP (in use) | $0 |
| S3, CloudWatch, IAM | cents at this volume |

`terraform destroy` when you are not using it. Setting
`enable_nat_gateway = false` removes the largest line item but breaks package
installs and CloudWatch log delivery on the web tier.

## Notes

- **`allowed_account_ids`** on the provider makes a stale `AWS_PROFILE` fail at
  provider configuration rather than quietly building the stack in the wrong
  account. It is the account-level counterpart to the `environment` validation
  in `variables.tf`. Set it to `[]` to disable.
- **`.terraform.lock.hcl` is committed**, not ignored. It pins the exact
  provider build and its verified hashes so every machine and CI runner
  resolves identically. Run `terraform providers lock` when you deliberately
  upgrade.
- **Locking** uses `use_lockfile = true` (S3-native conditional writes), which
  requires **Terraform 1.10+**. No DynamoDB table needed.
- `region` in the backend block is the bucket's region, and is independent of
  `var.aws_region` used for provisioning.
- State holds resource attributes in plaintext. Restrict `s3:GetObject` on the
  state bucket to the people and CI roles that actually run Terraform.
- `key_name` defaults to null, so no instance gets an SSH key. **SSM Session
  Manager still works** — every instance carries `AmazonSSMManagedInstanceCore`
  through its instance profile. Set `key_name` and `allowed_ssh_cidrs` only if
  you specifically want the bastion SSH path.
- `allowed_ssh_cidrs` rejects `0.0.0.0/0` by validation.
- `ami_id` defaults to null, which tracks the newest Amazon Linux 2023. A new
  AL2023 release will therefore plan an **instance replacement**. Pin it before
  you care about uptime.
- The admin IAM user is created **without an access key** — `aws_iam_access_key`
  writes the secret into Terraform state in plaintext. Create credentials in
  the console, or use federated access instead.
- ALB access logs are off by default (`alb_enable_access_logs`). Enabling them
  relies on `data.aws_elb_service_account`, which only covers regions launched
  before August 2022.

## Adding qa or production

See `env/qa/README.md` and `env/production/README.md`. Short version: copy
`env/dev/*` including `user_data/`, then change the state `key`, the
`environment` variable and its validation, and the tfvars. Reusing dev's state
key is the one mistake that really hurts — the new environment would adopt and
then modify dev's infrastructure.
