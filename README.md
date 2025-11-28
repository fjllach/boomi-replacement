# AWS Boomi Replacement

This project implements a serverless architecture on AWS to replace a legacy Boomi integration. It extracts data from Salesforce, stores it in S3, and orchestrates a process to send that data to an external API.

## Architecture

1.  **Extraction**: AWS AppFlow (simulated locally) extracts data from Salesforce.
2.  **Storage**: Data is saved as a JSON file in an Amazon S3 bucket.
3.  **Trigger**: An EventBridge rule detects the `Object Created` event in S3.
4.  **Orchestration**: AWS Step Functions is triggered by EventBridge.
5.  **Processing**: A Lambda function (Node.js/TypeScript) is invoked by the Step Function. It reads the file from S3 and POSTs the content to an external API.

## Project Structure

- `terraform/`: Infrastructure as Code (IaC) using Terraform.
- `src/`: TypeScript source code for the Lambda function.
- `mocks/`: Simple Node.js servers to mock Salesforce and the External API for local testing.
- `scripts/`: Helper scripts for simulation.

## Prerequisites

- Node.js (v18+)
- Docker & Docker Compose
- Terraform (for deployment)
- AWS CLI (optional, for manual verification)

## Local Simulation

You can run the entire flow locally using Docker and LocalStack.

1.  **Install Dependencies & Build**:
    ```bash
    npm install
    npm run build
    ```

2.  **Start the Environment**:
    ```bash
    docker-compose up
    ```
    This starts:
    - **LocalStack**: Simulating S3, Lambda, Step Functions, etc.
    - **Mock Salesforce**: `http://localhost:3001`
    - **Mock API**: `http://localhost:3002`
    - **Terraform Runner**: Automatically deploys the infrastructure to LocalStack.

    *Wait for the `terraform-runner` to finish applying.*

3.  **Trigger the Flow**:
    Open a new terminal and run the simulation script. This fetches data from the Mock Salesforce and uploads it to the LocalStack S3 bucket, triggering the pipeline.
    ```bash
    node scripts/simulate_flow.js
    ```

4.  **Verify**:
    - Check the **Mock API** logs in the Docker terminal. You should see "External API Received Data".
    - Check the **Mock Salesforce** logs for the query.

## Deployment to AWS

1.  **Configure Variables**:
    Create a `terraform.tfvars` file in the `terraform/` directory with your real values:
    ```hcl
    salesforce_connector_profile_name = "MySalesforceConnection"
    external_api_url                  = "https://api.example.com/ingest"
    ```

2.  **Deploy**:
    ```bash
    cd terraform
    terraform init
    terraform apply
    ```

## Development

- **Build TypeScript**: `npm run build`
- **Lint/Format**: (Add your linting commands here)
