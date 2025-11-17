# Infra Snapshot – Day 1

## AWS Region
- us-east-1

## EC2
- sci-agent-app
  - t3.medium, Ubuntu 22.04
  - SG: sci-agent-sg (SSH 22 from my IP, HTTP 80 open - if enabled)
  - EBS: 50 GB gp3
- sci-agent-research
  - c7i.large, Ubuntu 22.04
  - SG: sci-agent-sg
  - EBS: 100 GB gp3

## RDS
- PostgreSQL: db.t3.medium
- User: sci_admin
- Storage: 100 GB gp3

## S3
- Bucket: sci-discovery-data-<handle>

## SSH Key
- Name: sci-agent-key.pem
- Location: ~/.ssh/sci-agent-key.pem
