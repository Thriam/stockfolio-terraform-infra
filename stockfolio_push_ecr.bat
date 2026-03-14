@echo off
REM --------------------------------------------
REM Stockfolio ECR Push Script with Auto-Create
REM --------------------------------------------

REM Set AWS region and account
SET AWS_REGION=us-east-1
SET AWS_ACCOUNT_ID=197470385564
SET ECR_REPO_PREFIX=thriam/stockfolio

REM List of services
SET SERVICES=backend frontend wallet about market-data db

REM Login to ECR
echo Logging in to ECR...
aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com

REM Loop through services
FOR %%S IN (%SERVICES%) DO (
    echo.
    echo -------------------------------
    echo Processing service: %%S
    echo -------------------------------
    
    REM Check if repository exists, if not create
    aws ecr describe-repositories --repository-names %ECR_REPO_PREFIX%-%%S --region %AWS_REGION% >nul 2>&1
    IF ERRORLEVEL 1 (
        echo Repository does not exist. Creating %ECR_REPO_PREFIX%-%%S...
        aws ecr create-repository --repository-name %ECR_REPO_PREFIX%-%%S --region %AWS_REGION%
    ) ELSE (
        echo Repository already exists: %ECR_REPO_PREFIX%-%%S
    )

    REM Tag image
    IF "%%S"=="db" (
        docker tag mysql:8.0 %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/%ECR_REPO_PREFIX%-%%S:8.0
        docker push %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/%ECR_REPO_PREFIX%-%%S:8.0
    ) ELSE (
        docker tag navlipi/stockfolio-%%S:latest %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/%ECR_REPO_PREFIX%-%%S:latest
        docker push %AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/%ECR_REPO_PREFIX%-%%S:latest
    )
)

echo.
echo All images pushed successfully!
pause
