# Production-Grade Cloud Platform

This project creates a fully automated, self-healing, and disposable cloud platform on AWS.

## Architecture

```mermaid
graph TB
    %% Styling
    classDef aws fill:#232F3E,stroke:#FF9900,stroke-width:3px,color:#fff,font-size:14px;
    classDef compute fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#fff,font-size:13px,font-weight:bold;
    classDef db fill:#1f9e78,stroke:#232F3E,stroke-width:2px,color:#fff,font-size:13px,font-weight:bold;
    classDef net fill:#6366f1,stroke:#232F3E,stroke-width:2px,color:#fff,font-size:13px,font-weight:bold;
    classDef security fill:#dc2626,stroke:#232F3E,stroke-width:2px,color:#fff,font-size:13px,font-weight:bold;
    classDef external fill:#fff,stroke:#232F3E,stroke-width:3px,color:#232F3E,font-size:14px,font-weight:bold;

    %% External Actors
    User((End User)):::external
    GitHub((CI/CD<br/>GitHub Actions)):::external

    subgraph AWS ["AWS Cloud"]
        direction TB
        
        subgraph VPC ["VPC - Virtual Private Cloud"]
            
            subgraph PubNet ["Public Subnets - Internet Facing"]
                IGW["Internet<br/>Gateway"]:::net
                ALB["Application<br/>Load Balancer"]:::net
                NAT["NAT<br/>Gateway"]:::net
            end
            
            subgraph PrivNet ["Private Subnets - Isolated"]
                ECS["ECS Fargate<br/>Cluster"]:::compute
                RDS["RDS<br/>PostgreSQL"]:::db
            end
        end

        subgraph Support ["Supporting Services"]
            ECR["ECR<br/>Container Registry"]:::compute
            Secrets["Secrets<br/>Manager"]:::security
            CW["CloudWatch<br/>Logs & Metrics"]:::aws
        end
    end

    %% External Flows
    User -->|HTTPS:443| ALB
    GitHub -->|Terraform Apply| AWS

    %% Public Subnet Flows
    ALB -->|Route Traffic| ECS
    IGW -->|NAT Route| NAT
    NAT -->|Outbound Traffic| IGW

    %% Private Subnet Flows
    ECS -->|SQL Queries| RDS
    ECS -->|Pull Image| ECR
    ECS -->|Get Secrets| Secrets
    ECS -->|Send Logs| CW

    %% Styling subgraphs
    style AWS fill:#f8fafc,stroke:#232F3E,stroke-width:3px,color:#232F3E
    style VPC fill:#f0f9ff,stroke:#6366f1,stroke-width:2px,stroke-dasharray:10,5,color:#1e40af
    style PubNet fill:#fef3c7,stroke:#f59e0b,stroke-width:2px,color:#92400e
    style PrivNet fill:#dcfce7,stroke:#22c55e,stroke-width:2px,color:#166534
    style Support fill:#f5f3ff,stroke:#8b5cf6,stroke-width:2px,color:#5b21b6
```

- Compute: AWS ECS Fargate (Serverless Containers)
- Database: AWS RDS PostgreSQL (Private Subnets)
- Networking: VPC with Public/Private subnets, NAT Gateways
- Load Balancing: Application Load Balancer (ALB)
- Security: Least-privilege IAM roles, Security Groups, Secrets Manager, GuardDuty
- CI/CD: GitHub Actions for automated build and deploy

## prerequisites
- AWS Account
- GitHub Account
- Terraform installed
- AWS CLI installed and configured
- Docker installed

## Setup
1. Fork/Clone this repository.
2. Configure Secrets in GitHub/Local environment:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## Deployment
### Option 1: Via GitHub Actions
Push to the `main` branch. The `Deploy Platform` workflow will:
1. Provision Infrastructure.
2. Build & Push Docker Image.
3. Deploy Application to ECS.

### Option 2: Local Deployment
Run the automated script:
```bash
./scripts/deploy.sh
```

## Destruction
To completely tear down the environment:
```bash
./scripts/destroy.sh
```

## Resilience
The platform is designed to survive failure:
- Multi-AZ: Resources are spread across multiple Availability Zones.
- Auto-Healing: ECS automatically replaces failed containers. ALB ensures traffic only goes to healthy instances.
- Private Database: The database is isolated in private subnets, accessible only by the application.
