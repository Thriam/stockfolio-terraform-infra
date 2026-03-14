1️⃣ Create an ECS Task Execution Role

You only need to do this once per account/region:

aws iam create-role `
  --role-name ecsTaskExecutionRole `
  --assume-role-policy-document "{ `"Version`": `"2012-10-17`", `"Statement`": [{ `"Effect`": `"Allow`", `"Principal`": { `"Service`": `"ecs-tasks.amazonaws.com`" }, `"Action`": `"sts:AssumeRole`" }]}"


Attach the AmazonECSTaskExecutionRolePolicy managed policy:

aws iam attach-role-policy `
  --role-name ecsTaskExecutionRole `
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy


✅ This role allows ECS tasks to pull images from ECR and write logs to CloudWatch.

2️⃣ Update Task Definition JSONs

Add "executionRoleArn" pointing to the new role in all task definition JSONs:

Example for backend-taskdef.json:

{
  "family": "backend-task",
  "executionRoleArn": "arn:aws:iam::197470385564:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "197470385564.dkr.ecr.us-east-1.amazonaws.com/thriam/stockfolio-backend:latest",
      "essential": true,
      "portMappings": [
        { "containerPort": 8080, "protocol": "tcp" }
      ],
      "environment": [
        { "name": "SPRING_DATASOURCE_URL", "value": "jdbc:mysql://db:3306/stockdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true&createDatabaseIfNotExist=true" },
        { "name": "SPRING_DATASOURCE_USERNAME", "value": "root" },
        { "name": "SPRING_DATASOURCE_PASSWORD", "value": "root" },
        { "name": "WALLET_SERVICE_URL", "value": "http://wallet:8091" },
        { "name": "MARKET_DATA_BASE_URL", "value": "http://market-data:7666" }
      ]
    }
  ]
}


Add the same "executionRoleArn" line in all six task definition JSONs.