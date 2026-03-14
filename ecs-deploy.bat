@echo off
REM ==================================================
REM Stockfolio ECS Full Deployment Script (Windows)
REM ==================================================

SETLOCAL ENABLEDELAYEDEXPANSION

REM ------------------------
REM AWS and ECR Settings
REM ------------------------
SET AWS_REGION=us-east-1
SET AWS_ACCOUNT_ID=197470385564
SET ECR_REPO_PREFIX=thriam/stockfolio
SET CLUSTER_NAME=stockfolio-cluster
SET VPC_ID=vpc-0071748a3869e0ed0

REM ------------------------
REM Security Group
REM ------------------------
echo Checking for existing security group...
for /f "tokens=*" %%G in ('aws ec2 describe-security-groups --filters "Name=group-name,Values=stockfolio-sg" --query "SecurityGroups[0].GroupId" --output text --region %AWS_REGION%') do set SECURITY_GROUP=%%G

IF "%SECURITY_GROUP%"=="None" (
    echo Security group does not exist. Creating...
    for /f "tokens=*" %%G in ('aws ec2 create-security-group --group-name stockfolio-sg --description "Stockfolio ECS SG" --vpc-id %VPC_ID% --query "GroupId" --output text --region %AWS_REGION%') do set SECURITY_GROUP=%%G

    echo Adding inbound rules...
    aws ec2 authorize-security-group-ingress --group-id !SECURITY_GROUP! --protocol tcp --port 80 --cidr 0.0.0.0/0 --region %AWS_REGION%
    aws ec2 authorize-security-group-ingress --group-id !SECURITY_GROUP! --protocol tcp --port 8080-8091 --cidr 0.0.0.0/0 --region %AWS_REGION%
)
echo Using Security Group: !SECURITY_GROUP!

REM ------------------------
REM Get two public subnets (comma-separated)
REM ------------------------
set SUBNETS=

for /f "tokens=*" %%S in ('aws ec2 describe-subnets --filters "Name=vpc-id,Values=%VPC_ID%" "Name=map-public-ip-on-launch,Values=true" --query "Subnets[0].SubnetId" --output text --region %AWS_REGION%') do set SUBNET1=%%S
for /f "tokens=*" %%S in ('aws ec2 describe-subnets --filters "Name=vpc-id,Values=%VPC_ID%" "Name=map-public-ip-on-launch,Values=true" --query "Subnets[1].SubnetId" --output text --region %AWS_REGION%') do set SUBNET2=%%S

set SUBNETS=%SUBNET1%,%SUBNET2%
echo Using Subnets: !SUBNETS!

REM ------------------------
REM ECR Login
REM ------------------------
echo Logging in to ECR...
aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com

REM ------------------------
REM Create ECS Cluster
REM ------------------------
aws ecs describe-clusters --clusters %CLUSTER_NAME% --region %AWS_REGION% >nul 2>&1
IF ERRORLEVEL 1 (
    echo Creating ECS cluster: %CLUSTER_NAME%
    aws ecs create-cluster --cluster-name %CLUSTER_NAME% --region %AWS_REGION%
) ELSE (
    echo ECS cluster already exists: %CLUSTER_NAME%
)

REM ------------------------
REM Deploy Services
REM ------------------------
SET SERVICES=backend frontend wallet about market-data db

FOR %%S IN (%SERVICES%) DO (
    echo.
    echo Deploying service: %%S

    REM Register task definition
    aws ecs register-task-definition --cli-input-json file://taskdefs/%%S-taskdef.json --region %AWS_REGION%

    REM Create ECS service
    aws ecs create-service --cluster %CLUSTER_NAME% --service-name %%S-service --task-definition %%S-task --desired-count 1 --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[!SUBNETS!],securityGroups=[!SECURITY_GROUP!],assignPublicIp=ENABLED}" --region %AWS_REGION%
)

echo.
echo ==================================================
echo All Stockfolio services deployed successfully!
echo Check ECS cluster tasks to get frontend public IP.
pause
