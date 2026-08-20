# production — not yet provisioned

To stand this environment up, copy dev and change what differs:

```bash
cp -r ../dev/*.tf ../dev/terraform.tfvars ../dev/user_data .
```

Then edit:

1. **`backend.tf`** — set `key = "ec2-demo/production/terraform.tfstate"`.
   Leave `bucket` and `region` alone; all environments share one state bucket
   and are separated by key. Reusing dev's key would have production manage
   dev's infrastructure.
2. **`variables.tf`** — change the `environment` default and its validation
   from `dev` to `production`.
3. **`terraform.tfvars`** — set `environment = "production"` plus real sizing.

Then `terraform init && terraform plan`.

## Worth tightening before this goes live

Dev's defaults are convenience choices, not production ones:

- **Pin `ami_id`.** It defaults to null, which tracks the newest Amazon Linux
  2023. A new AL2023 release then shows up as an instance replacement in a
  routine plan.
- **One NAT gateway, in `public-a`.** If that AZ fails, the private subnet in
  the other AZ loses outbound internet. Create one per AZ and point each
  private route table at the NAT in its own zone.
- **HTTP only.** The ALB listens on port 80 with no certificate. Production
  wants an ACM certificate, a 443 listener, and a 80→443 redirect.
- **`s3_force_destroy = true`** lets `terraform destroy` delete a bucket that
  still holds logs. Set it to false.
- **`enable_deletion_protection` on the ALB** is false. Turn it on, and
  consider `prevent_destroy` on the instances and the application bucket.
- **`t3.micro` and a 20 GiB root volume** — size for actual load. Consider
  replacing the two static instances with a launch template and an Auto
  Scaling Group, which is what the architecture diagram sketches.
- **The admin IAM user's `ec2:*` and `elasticloadbalancing:*`** are broad.
  Narrow them to named actions, and prefer federated access over a user.
- **A separate AWS account**, or at minimum a distinct IAM role for production
  applies, plus `allowed_account_ids` on the provider so a stale `AWS_PROFILE`
  fails fast.
- **No backups.** Nothing snapshots the EBS volumes. Add AWS Backup or a DLM
  lifecycle policy if the instances hold anything you would miss.
