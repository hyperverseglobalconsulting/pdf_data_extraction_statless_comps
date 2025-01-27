# AWS GPU-Powered PDF Processing System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A scalable solution for processing PDF research papers using AWS Fargate GPU tasks, S3, SQS, and DocumentDB.

**Note:** This README will evolve as we implement different components of the system.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Current Features](#current-features)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Architecture Overview
```mermaid
%% AWS Architecture with Isolated DocumentDB Subnet
graph TD
    A[User] -->|Upload PDF| B[(Amazon S3)]
    
    subgraph AWS["AWS Cloud"]
        subgraph VPC["VPC (10.0.0.0/16)"]
            subgraph PublicSubnet["Public Subnet"]
                I[Internet Gateway]
            end
            
            subgraph PrivateSubnet1["Private Subnet 1 (ECS & Lambda)"]
                H[AWS Lambda]
                D[ECS Fargate Tasks]
                E[VPC Endpoints]
            end
            
            subgraph PrivateSubnet2["Private Subnet 2 (DB)"]
                F[(Amazon DocumentDB)]
            end
        end
        
        B -->|Event Notification| C{Amazon SQS}
        C -->|Triggers| H
        H -->|Invokes| D
        D -->|Pull PDF| B
        D -->|Store Extracted Images| B
        D -->|Save Metadata| F
        D -->|Logs| G[Amazon CloudWatch]
        H -->|Logs| G
    end
    
    %% Class Definitions
    classDef aws fill:#e6f3ff,stroke:#0066cc,color:#000;
    classDef vpc fill:#e6ffe6,stroke:#008000,color:#000;
    classDef public fill:#ffe6e6,stroke:#cc0000,color:#000;
    classDef private1 fill:#f0e6ff,stroke:#6600cc,color:#000;
    classDef private2 fill:#e6f0ff,stroke:#0044cc,color:#000;
    classDef service fill:#fff5e6,stroke:#cc8800,color:#000;
    
    %% Apply Styles
    class AWS aws;
    class VPC vpc;
    class PublicSubnet public;
    class PrivateSubnet1 private1;
    class PrivateSubnet2 private2;
    class B,C,F,G,I,D,E,H service;
```

Components:
- **S3 Bucket**: PDF storage with event notifications
- **SQS FIFO Queue**: Message broker for processing tasks
- **Fargate GPU Tasks**: OCR and layout parsing using LayoutParser/PaddleOCR
- **DocumentDB**: Structured storage of extracted content
- **VPC with Private Subnets**: Secure networking without NAT Gateway

## Current Features
✅ **Implemented**  
- Terraform infrastructure as code
- VPC configuration with cost-optimized networking
- S3 + SQS integration
- GPU-optimized ECS cluster setup
- DocumentDB cluster configuration

🛠 **In Progress**  
- OCR processing container implementation
- Auto-scaling policies
- Monitoring integration

## Prerequisites
- AWS Account with appropriate permissions
- Terraform v1.5.0+
- AWS CLI configured
- Docker (for container development)
- GPU-enabled Docker runtime (for local testing)

## Deployment

### Initial Setup
```bash
# Clone repository
git clone https://github.com/hyperverseglobalconsulting/pdf_data_extraction_statless_comps.git
cd pdf_data_extraction_statless_comps

# Initialize Terraform
terraform init

# Review execution plan
terraform plan -out=tfplan
```
## Infrastructure Provisioning
```bash
# Apply configuration
terraform apply tfplan

# Outputs will show:
# - S3 bucket name
# - DocumentDB endpoint
# - SQS queue URL
```
## Destroying Resources
```bash
terraform destroy
```
## Configuration

### Environment Variables
| Variable               | Description                     | Required |
|------------------------|---------------------------------|----------|
| `AWS_PROFILE`          | CLI credential profile          | Yes      |
| `TF_VAR_docdb_password`| DocumentDB admin password       | Yes      |

### Service Configuration
Update `variables.tf` for:
- AWS region
- Cluster sizing
- Auto-scaling thresholds
- GPU requirements

## Cost Optimization
- **VPC Design**: Uses interface endpoints instead of NAT Gateway  
- **Fargate Spot**: Add spot pricing configuration  
- **DocumentDB**: T3 instances for dev/test environments  
- **S3 Lifecycle**: Add rules for PDF versioning  

## Troubleshooting
**Common Issues:**  
- 🛠 **GPU Driver Errors**: Ensure NVIDIA container toolkit is installed  
- 📨 **S3 Event Delivery**: Check SQS access policy and bucket notification  
- ⏱ **VPC Endpoint Timeouts**: Validate security group rules  
- 🔌 **DocumentDB Connectivity**: Verify subnet group associations  

## Roadmap
### Phase 1: Core Infrastructure (Current)
- [x] Terraform base configuration  
- [ ] Monitoring integration  
- [ ] CI/CD pipeline setup  

### Phase 2: Processing Implementation
- [ ] OCR container development  
- [ ] Performance benchmarking  
- [ ] Load testing  

### Phase 3: Optimization
- [ ] Cold start mitigation  
- [ ] Multi-model inference  
- [ ] Cost alerts  

## Contributing
1. Fork the repository  
2. Create feature branch: `git checkout -b feature/improvement`  
3. Commit changes  
4. Push to branch  
5. Open PR  

## License  
MIT License - see [LICENSE](LICENSE) for details
