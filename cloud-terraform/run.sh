#!/bin/bash
# Cloud & Terraform in Action (Session 19): VPC + subnets + IGW + routes + SG + EC2 + S3.
# Runs against a local AWS emulator (Moto) so no real AWS account is needed:
#   docker run -d --name moto -p 4566:5000 motoserver/moto:latest      and   pip install boto3
# Usage: ./run.sh            (set SHOT_DIR=/some/dir to also save each step's output to a file)
set -e
cd "$(dirname "$0")"

CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
export TF_IN_AUTOMATION=1 TF_CLI_ARGS="-no-color"
python3 -c "import boto3" 2>/dev/null || { echo "verify_infra.py needs boto3: pip install boto3"; exit 1; }
docker start moto >/dev/null 2>&1 || docker run -d --name moto -p 4566:5000 motoserver/moto:latest >/dev/null
sleep 2

shot 01-init-validate
run terraform init
run terraform fmt -check -recursive
run terraform validate

shot 02-plan
run "terraform plan -out=tfplan | grep -E '^  # |Plan:|Changes to Outputs|^  \+ [a-z_]+ += '"

shot 03-apply
run "terraform apply tfplan | grep -E 'Creating|Creation complete|Apply complete|^[a-z_]+ = |^  \"|^\]'"

shot 04-dependencies
run "terraform graph | grep -- ' -> ' | grep -v -E 'provider|close|meta|root' | sort"

shot 05-state-output
run terraform state list
run "terraform state show aws_instance.web | grep -E '^resource|^ +(ami|instance_type|instance_state|private_ip|public_ip|subnet_id|vpc_security_group_ids|id) +='"
run terraform output

shot 06-verify
run python3 verify_infra.py http://localhost:4566

shot 07-change
run "terraform plan -var instance_type=t3.small | grep -E '^  # |instance_type|Plan:'"
run "terraform apply -auto-approve -var instance_type=t3.small | grep -E 'Modifying|Modifications complete|Apply complete'"
run "python3 verify_infra.py http://localhost:4566 | grep EC2"
run "terraform apply -auto-approve | grep -E 'Modifying|Apply complete'"

shot 08-idempotent
run "terraform plan -detailed-exitcode | tail -3"

shot 09-destroy
run "terraform destroy -auto-approve | grep -E 'Destroying|Destruction complete|Destroy complete' | tail -12"
run terraform state list
run python3 verify_infra.py http://localhost:4566
rm -f tfplan
