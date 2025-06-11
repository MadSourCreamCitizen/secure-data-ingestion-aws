# secure-data-ingestion-aws
An AWS project demonstrating a secure, automated pipeline for simulated healthcare data, focusing on HIPPA-like compliance and IaC


---

# Secure Healthcare Data Ingestion Pipeline on AWS

This project demonstrates the foundational components of a secure, automated, and event-driven pipeline for ingesting and preparing simulated patient data in a cloud environment. Developed as a hands-on learning exercise, this solution leverages Infrastructure as Code (IaC) with **Terraform** to provision highly secure AWS services, focusing on critical healthcare data protection principles relevant for provider and payer ecosystems.

## Project Overview

The pipeline is designed to securely receive simulated patient data, automatically process it, and store it in a designated processed data store. This approach ensures data integrity, confidentiality, and scalability from the moment of ingestion.

## Architecture

```
+----------------+          +------------------------+          +-------------------+          +-------------------+
|  Source System |          | AWS S3 (Raw Data)      |          | AWS Lambda Function |          | AWS S3 (Processed)|
| (e.g., Local   +--------->|  - Secure-patient-data |          |  - Data Processor   |          |  - Secure-processed |
|  Upload via CLI)|          |  - Versioning Enabled  |          |  - Python Runtime   |          |  - Versioning Enabled |
|                |          |  - KMS Encrypted       |          |  - IAM Role (Least |          |  - KMS Encrypted    |
|                |          |  - Public Access Block |          |    Privilege)       |          |  - Public Access Block|
|                |          |  - Event Notification  +--------->|  - Triggered by S3  |          |                   |
+----------------+          +------------------------+          |  - Logs to CloudWatch|          +-------------------+
                                                                |                     |
                                                                +----------+----------+
                                                                           |
                                                                           |
                                                                           v
                                                                +-------------------+
                                                                | AWS CloudWatch Logs |
                                                                | (for monitoring/    |
                                                                |  debugging Lambda)  |
                                                                +-------------------+
```

## Key Features Implemented

* **Infrastructure as Code (IaC) with Terraform:** All cloud resources are defined, deployed, and managed using Terraform, ensuring repeatability, consistency, and version control of the infrastructure.
* **Secure Data Ingestion (Amazon S3):**
    * Dedicated S3 bucket (`secure-patient-data-`) for raw data ingestion.
    * **Versioning enabled** for data recovery and auditability.
    * **Strict Public Access Blocking** (all `block_public_acls`, `block_public_network_acls`, `ignore_public_acls`, `restrict_public_buckets`, `block_public_policy` set to `true`) to prevent accidental data exposure.
    * **AWS Key Management Service (KMS) Encryption:** All data at rest in the raw S3 bucket is automatically encrypted using a dedicated, customer-managed KMS key.
* **Automated Data Processing (AWS Lambda):**
    * Serverless Python Lambda function (`SecurePatientDataProcessor-`) automatically triggered by S3 object creation events in the raw data bucket (specifically for objects uploaded to the `raw/` prefix).
    * The Lambda function reads the encrypted raw data, simulates processing (e.g., adds a "processed" header), and writes it to a separate bucket.
* **Secure Processed Data Storage (Amazon S3):**
    * Separate S3 bucket (`secure-processed-data-`) for storing data after Lambda processing.
    * Configured with the same high-security standards (versioning, public access blocking, KMS encryption).
* **Granular Permissions (IAM):**
    * Dedicated IAM Role and Policy for the Lambda function, adhering strictly to the principle of least privilege, granting only necessary access to S3, KMS, and CloudWatch Logs.
    * KMS Key Policy explicitly allowing the Lambda's role to perform cryptographic operations.
* **Centralized Logging (CloudWatch):** Lambda function execution logs are automatically sent to CloudWatch for monitoring, debugging, and auditing purposes.
* **AWS Free Tier Compliance:** All deployed resources and their configurations are designed to operate within the AWS Free Tier limits, making this a cost-effective learning project.

## Key Learnings & Challenges Overcome: A Deeper Dive

Beyond the core technical implementation, this project significantly enhanced my problem-solving and critical thinking abilities, particularly in navigating and troubleshooting unexpected issues:

* **Navigating Inconsistent Information & Verifying Official Sources:**
    * During the setup phase, there was a persistent and critical discrepancy regarding the **latest stable version of Terraform CLI**. Initially, guided by the provided assistance (Gemini), attempts were made to "upgrade" Terraform CLI to what was mistakenly believed to be a newer version (e.g., `v1.8.x`), despite the system consistently reporting `v1.12.1` as the latest it could find from its `apt` package manager. This mismatch led to confusion and unnecessary troubleshooting of `apt` repositories.
    * This misdirection, originating from **Gemini's flawed information**, led to further issues including an accidental uninstallation of Terraform CLI.
    * Through **diligent verification and insistent cross-referencing with official HashiCorp release pages**, I successfully identified that **Terraform CLI `v1.12.1` was, in fact, the actual latest stable version** (as of May 21, 2025). This required me to critically evaluate conflicting data and trust my own research against the provided, erroneous guidance, ultimately requiring a manual installation to ensure the correct binary was in use.
    * **Impact:** This experience highlighted the crucial importance of always verifying information against primary, official documentation, especially when troubleshooting unexpected behavior. It solidified my ability to identify and correct flawed data, a vital skill in any technical role.

* **Adapting to AWS Provider Syntax Changes (AWS Provider v5.x.x):**
    * Even with the correct Terraform CLI version (`v1.12.1`), the project encountered `Unsupported block type` errors (`lambda_configuration`) within the `aws_s3_bucket_notification` resource.
    * This required in-depth research into the AWS Provider `v5.x.x` documentation on the Terraform Registry to identify the precise, updated syntax (specifically, the correct use of `lambda_function` block and `filter_prefix` argument for S3 notifications).
    * **Impact:** This scenario underscored the dynamic nature of cloud provider APIs and Terraform provider versions, emphasizing the need for continuous learning and meticulous attention to documentation for successful IaC deployments.

* **Debugging Granular IAM/KMS Permissions (Two-Sided Policies):**
    * A significant hurdle involved an `AccessDenied` error during the Lambda's execution, specifically related to `kms:Decrypt`. While the Lambda's IAM role initially had `kms:Decrypt` permission in its identity-based policy, the error indicated that the **KMS Key's own resource-based policy** did not grant the Lambda's role permission to use the key.
    * **Impact:** This experience provided hands-on understanding of KMS's "two-sided" permission model (identity-based policy + resource-based policy) and the importance of ensuring both sides explicitly grant access for secure cross-service interaction.

* **Troubleshooting Subtle CLI/Shell Interactions:**
    * Initial attempts to upload files to S3 via the AWS CLI failed with `NoSuchBucket` errors, even when the bucket name seemed correct. This was traced back to issues like accidentally literal use of placeholder names or, more subtly, extra quotes being included in shell variable substitutions from `terraform output`.
    * **Impact:** This reinforced the need for precision in shell scripting and understanding how CLI commands interact with environment variables and command substitution.

## Getting Started (Deployment Instructions)

1.  **Prerequisites:**
    * An AWS account (with configured Free Tier if applicable).
    * AWS CLI installed and configured with programmatic access credentials (IAM User with necessary permissions) for your desired region.
    * WSL (Windows Subsystem for Linux) if on Windows, or a Linux/macOS environment.
    * Terraform CLI (`v1.12.1` or later recommended) installed on your system.
    * VS Code (recommended) with the "Remote - WSL" (if applicable) and HashiCorp Terraform extensions.
    * `unzip` utility installed in your WSL/Linux environment (`sudo apt install unzip`).

2.  **Clone the Repository:**
    ```bash
    git clone https://github.com/your-github-username/secure-data-ingestion-aws.git
    cd secure-data-ingestion-aws/terraform/
    ```
    (Replace `your-github-username` with your actual GitHub username.)

3.  **Update AWS Region:**
    Open `main.tf` in your `terraform/` directory using VS Code (`code .` from your project root). Update the `region` in the `provider "aws"` block and the `default` value of the `aws_region` variable to your preferred AWS region.

4.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

5.  **Review Proposed Changes:**
    ```bash
    terraform plan
    ```
    Carefully review the output. It should show ~15 resources to be added (initial infrastructure plus Lambda components).

6.  **Apply Changes:**
    ```bash
    terraform apply
    ```
    Type `yes` when prompted to confirm the deployment.

## Testing the Pipeline

1.  **Create Sample Data:**
    Navigate to the `sample_data/` directory in your local project (`secure-data-ingestion-aws/sample_data/`). Create a file named `patient_data_1.csv` with simulated data:
    ```csv
    patient_id,first_name,last_name,date_of_birth,gender,medical_record_number
    1001,John,Doe,1980-01-15,Male,MRN-123456
    1002,Jane,Smith,1992-05-20,Female,MRN-789012
    ```

2.  **Upload to Raw S3 Bucket:**
    From your `secure-data-ingestion-aws/terraform/` directory:
    ```bash
    RAW_BUCKET_NAME=$(terraform output raw_data_bucket_name | tr -d '"')
    aws s3 cp ../sample_data/patient_data_1.csv s3://${RAW_BUCKET_NAME}/raw/patient_data_1.csv
    ```

3.  **Verify Lambda Execution (CloudWatch Logs):**
    * Log into the AWS Management Console (ensure correct region: e.g., `us-east-1`).
    * Navigate to **CloudWatch** -> **Log groups**.
    * Find `/aws/lambda/SecurePatientDataProcessor-...` and check the **most recent log stream** for execution details, including:
        * "Successfully retrieved file..."
        * "Processed data written successfully..."

4.  **Verify Processed Data (Processed S3 Bucket):**
    * In the AWS Management Console (ensure correct region), navigate to **S3**.
    * Find your `secure-processed-data-...` bucket.
    * Navigate into the `processed/` folder. You should find a new file (e.g., `YYYYMMDDHHMMSS_patient_data_1.csv`) containing the processed data.

## Cleanup (Important for Cost Management)

When you are finished experimenting with the project and want to de-provision all resources created by Terraform, run the following command from your `secure-data-ingestion-aws/terraform/` directory:

```bash
terraform destroy
```
Type `yes` when prompted to confirm the destruction of resources.

## Future Enhancements

* **Advanced Lambda Processing:** Implement actual data anonymization (e.g., using Faker library for synthetic data generation in testing, or proper hashing for PII in production), validation, or transformation logic.
* **Error Handling & DLQ:** Configure a Dead-Letter Queue (DLQ) for the Lambda function to capture failed invocations for later inspection and reprocessing.
* **Notifications:** Integrate SNS (Simple Notification Service) for alerts on successful processing or failures.
* **Data Cataloging:** Integrate with AWS Glue Data Catalog for schema management.
* **Orchestration:** Use AWS Step Functions to orchestrate more complex multi-step workflows.
* **Monitoring & Alarms:** Set up CloudWatch metrics and alarms for Lambda errors, S3 bucket size, etc.
* **CI/CD Pipeline:** Automate deployments using GitHub Actions, AWS CodePipeline, etc.
* **Terraform Remote State:** Configure a remote backend (e.g., S3 + DynamoDB) for Terraform state management to enable team collaboration and state locking.

## Acknowledgements

This project was developed as part of a guided learning experience. Special thanks to **Gemini (Google's AI)** for providing the initial project idea, architectural guidance, and step-by-step support.

It is important to note that during the development process, challenges arose due to **inaccurate and hallucinated information provided by Gemini**, particularly concerning Terraform CLI versioning and specific AWS provider syntax details. My persistence in identifying and correcting these errors through independent verification and official documentation was crucial for the project's successful completion. While core concepts and assistance were provided, all troubleshooting, debugging, and final code implementation reflect my hands-on learning and problem-solving process.