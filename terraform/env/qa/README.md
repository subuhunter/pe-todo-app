# qa — not yet provisioned

To stand this environment up, copy dev and change what differs:

```bash
cp -r ../dev/*.tf ../dev/terraform.tfvars ../dev/user_data .
```

Then edit:

1. **`backend.tf`** — set `key = "ec2-demo/qa/terraform.tfstate"`.
   Leave `bucket` and `region` alone; all environments share one state bucket
   and are separated by key. Reusing dev's key would have qa manage dev's
   instance.
2. **`variables.tf`** — change the `environment` default and its validation
   from `dev` to `qa`.
3. **`terraform.tfvars`** — set `environment = "qa"` plus any sizing changes.

Then `terraform init && terraform plan`.

Nothing here is shared with dev at runtime — each environment is an independent
root module with its own state. The only shared code is `../../modules/ec2`.
