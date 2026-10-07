"""Read back what Terraform created, using signed AWS API calls (boto3).

Usage: python3 verify_bucket.py <bucket> [endpoint]   (pip install boto3)
"""
import sys

import boto3

bucket = sys.argv[1]
endpoint = sys.argv[2] if len(sys.argv) > 2 else None
kwargs = {"region_name": "ap-south-1"}
if endpoint:  # local emulator: dummy credentials
    kwargs.update(endpoint_url=endpoint, aws_access_key_id="test", aws_secret_access_key="test")
s3 = boto3.client("s3", **kwargs)

print("Buckets:     ", [b["Name"] for b in s3.list_buckets()["Buckets"]])
print("Versioning:  ", s3.get_bucket_versioning(Bucket=bucket).get("Status"))
rule = s3.get_bucket_encryption(Bucket=bucket)["ServerSideEncryptionConfiguration"]["Rules"][0]
print("Encryption:  ", rule["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"])
print("PublicBlock: ", s3.get_public_access_block(Bucket=bucket)["PublicAccessBlockConfiguration"])
print("Tags:        ", {t["Key"]: t["Value"] for t in s3.get_bucket_tagging(Bucket=bucket)["TagSet"]})
print("hello.txt:   ", s3.get_object(Bucket=bucket, Key="hello.txt")["Body"].read().decode().strip())
