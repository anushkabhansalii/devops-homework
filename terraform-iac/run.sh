#!/bin/bash
# Terraform & IaC homework (Session 18): full workflow for an S3 bucket.
# Runs against a local AWS emulator (Moto) so no real AWS account is needed:
#   docker run -d --name moto -p 4566:5000 motoserver/moto:latest
# Usage: ./run.sh            (set SHOT_DIR=/some/dir to also save each step's output to a file)
set -e
cd "$(dirname "$0")"

CUR=/dev/null
shot() { [ -n "$SHOT_DIR" ] && { mkdir -p "$SHOT_DIR"; CUR="$SHOT_DIR/$1.txt"; : > "$CUR"; }; echo; echo "### $1 ###"; }
run()  { echo "\$ $*" | tee -a "$CUR"; bash -c "$*" 2>&1 | tee -a "$CUR"; echo | tee -a "$CUR"; }
export TF_IN_AUTOMATION=1 TF_CLI_ARGS="-no-color"
python3 -c "import boto3" 2>/dev/null || { echo "verify_bucket.py needs boto3: pip install boto3"; exit 1; }

docker start moto >/dev/null 2>&1 || docker run -d --name moto -p 4566:5000 motoserver/moto:latest >/dev/null
sleep 2

shot 01-emulator
run docker ps --filter name=moto --format "'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'"
run terraform version

cd terraform-s3-demo
shot 02-init
run terraform init

shot 03-fmt-validate
run terraform fmt -check -diff
run terraform validate

shot 04-plan
run terraform plan -out=tfplan

shot 05-apply
run terraform apply tfplan

shot 06-show-output
run terraform state list
run "terraform show | sed -n '/aws_s3_bucket.demo:/,/^}/p' | grep -E 'resource|arn |bucket |region |force_destroy|Environment|ManagedBy'"
run terraform output
run terraform output -raw bucket_arn
run "curl -s -o /dev/null -w 'anonymous GET hello.txt -> HTTP %{http_code}\\n' http://localhost:4566/anushka-devops-session18-demo/hello.txt"
run python3 verify_bucket.py anushka-devops-session18-demo http://localhost:4566

shot 07-idempotent
run terraform plan -detailed-exitcode

shot 08-destroy
run terraform destroy -auto-approve
run terraform state list
run "python3 verify_bucket.py anushka-devops-session18-demo http://localhost:4566 2>&1 | tail -1"
rm -f tfplan
