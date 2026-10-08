"""Independently check (with the AWS API, not Terraform) that the infrastructure exists and is wired correctly.

Usage: python3 verify_infra.py [endpoint]      (pip install boto3; uses normal AWS credentials if no endpoint)
"""
import sys

import boto3

kw = {"region_name": "ap-south-1"}
if len(sys.argv) > 1:
    kw.update(endpoint_url=sys.argv[1], aws_access_key_id="test", aws_secret_access_key="test")
ec2, s3 = boto3.client("ec2", **kw), boto3.client("s3", **kw)
tag = lambda r, k="Name": {t["Key"]: t["Value"] for t in r.get("Tags", [])}.get(k, "-")
flt = [{"Name": "tag:Project", "Values": ["session19"]}]

for v in ec2.describe_vpcs(Filters=flt)["Vpcs"]:
    print(f"VPC      {v['VpcId']}  {v['CidrBlock']}  {tag(v)}")
for s in sorted(ec2.describe_subnets(Filters=flt)["Subnets"], key=lambda s: s["CidrBlock"]):
    print(f"Subnet   {s['SubnetId']}  {s['CidrBlock']:<15} {s['AvailabilityZone']}  public_ip_on_launch={s['MapPublicIpOnLaunch']}  {tag(s)}")
for g in ec2.describe_internet_gateways(Filters=flt)["InternetGateways"]:
    print(f"IGW      {g['InternetGatewayId']}  attached to {g['Attachments'][0]['VpcId']}")
for rt in ec2.describe_route_tables(Filters=flt)["RouteTables"]:
    routes = ", ".join(f"{r.get('DestinationCidrBlock')}->{r.get('GatewayId', 'local')}" for r in rt["Routes"])
    print(f"Routes   {tag(rt):<20} {routes}  ({len(rt['Associations'])} subnets)")
for sg in ec2.describe_security_groups(Filters=flt)["SecurityGroups"]:
    rules = ", ".join(f"{p['FromPort']}/{p['IpProtocol']} from {p['IpRanges'][0]['CidrIp']}" for p in sg["IpPermissions"])
    print(f"SG       {sg['GroupId']}  {sg['GroupName']}: {rules}")
for r in ec2.describe_instances(Filters=flt)["Reservations"]:
    for i in r["Instances"]:
        print(f"EC2      {i['InstanceId']}  {i['InstanceType']}  {i['State']['Name']}  private={i.get('PrivateIpAddress')}  public={i.get('PublicIpAddress')}  subnet={i['SubnetId']}")
for b in s3.list_buckets()["Buckets"]:
    if b["Name"].startswith("session19"):
        print(f"S3       {b['Name']}  versioning={s3.get_bucket_versioning(Bucket=b['Name']).get('Status')}")
