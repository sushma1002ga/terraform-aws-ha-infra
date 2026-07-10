/**
 * Jenkins CI/CD Pipeline for Terraform AWS HA Infrastructure
 *
 * This pipeline manages BOTH infrastructure AND application deployment
 * across dev, qa, and prod environments.
 *
 * Flow:
 *   1. Infrastructure: Terraform init → plan → approve → apply
 *   2. Application:    Backend (Docker → ECR → ECS) + Frontend (S3 → CloudFront)
 *   3. Database:       Optional first-run schema init via bastion
 *
 * Prerequisites:
 *   - Jenkins with Pipeline plugin
 *   - Terraform >= 1.6 installed on agents
 *   - Docker installed on agents
 *   - AWS CLI v2 installed on agents
 *   - AWS credentials configured (Jenkins credentials or IAM role)
 *   - S3 backend bucket and DynamoDB table created
 *
 * Parameters:
 *   - ENVIRONMENT: Target environment (dev, qa, prod)
 *   - ACTION: Terraform action (plan, apply, destroy)
 *   - DEPLOY_APP: Deploy application after infrastructure apply
 *   - INIT_DB: Run database schema init (first-time only)
 *   - AUTO_APPROVE: Skip manual approval (dev only)
 */

pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment to deploy'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to perform'
        )
        booleanParam(
            name: 'DEPLOY_APP',
            defaultValue: true,
            description: 'Deploy backend + frontend after Terraform apply'
        )
        booleanParam(
            name: 'INIT_DB',
            defaultValue: false,
            description: 'Run database schema init (first-time setup only)'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Auto-approve apply (dev only, ignored for qa/prod)'
        )
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'
        AWS_REGION       = 'us-east-1'
        TF_VAR_FILE      = "environments/${params.ENVIRONMENT}.tfvars"
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 90, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    stages {

        // =====================================================================
        //  PHASE 1: INFRASTRUCTURE (Terraform)
        // =====================================================================

        // ─── Stage 1: Checkout ───────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                sh 'terraform version'
            }
        }

        // ─── Stage 2: Initialize ────────────────────────────────────────────
        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    sh '''
                        terraform init \
                            -backend-config="bucket=terraform-ha-infra-state" \
                            -backend-config="key=infrastructure/terraform.tfstate" \
                            -backend-config="region=${AWS_REGION}" \
                            -backend-config="dynamodb_table=terraform-ha-infra-lock" \
                            -backend-config="encrypt=true" \
                            -no-color
                    '''
                }
            }
        }

        // ─── Stage 3: Workspace ─────────────────────────────────────────────
        stage('Select Workspace') {
            steps {
                sh """
                    terraform workspace select ${params.ENVIRONMENT} || \
                    terraform workspace new ${params.ENVIRONMENT}
                """
                sh 'terraform workspace show'
            }
        }

        // ─── Stage 4: Validate ──────────────────────────────────────────────
        stage('Validate') {
            steps {
                sh 'terraform fmt -check -recursive -diff'
                sh 'terraform validate -no-color'
            }
        }

        // ─── Stage 5: Plan ──────────────────────────────────────────────────
        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    script {
                        def planCommand = "terraform plan -var-file=${TF_VAR_FILE} -out=tfplan -no-color"
                        if (params.ACTION == 'destroy') {
                            planCommand = "terraform plan -var-file=${TF_VAR_FILE} -destroy -out=tfplan -no-color"
                        }
                        sh planCommand
                    }

                    // Archive the plan for review
                    sh 'terraform show -no-color tfplan > tfplan.txt'
                    archiveArtifacts artifacts: 'tfplan.txt', fingerprint: true
                }
            }
        }

        // ─── Stage 6: Manual Approval (qa/prod only) ────────────────────────
        stage('Approval') {
            when {
                expression {
                    return params.ACTION != 'plan' && (
                        params.ENVIRONMENT != 'dev' || !params.AUTO_APPROVE
                    )
                }
            }
            steps {
                script {
                    def planOutput = readFile('tfplan.txt')
                    def approvalMsg = """
                        Environment: ${params.ENVIRONMENT}
                        Action: ${params.ACTION}

                        Please review the Terraform plan above and approve to proceed.

                        Plan Summary (last 20 lines):
                        ${planOutput.split('\n').takeRight(20).join('\n')}
                    """.stripIndent()

                    timeout(time: 30, unit: 'MINUTES') {
                        input message: approvalMsg,
                              ok: "Approve ${params.ACTION}",
                              submitter: 'infra-approvers'
                    }
                }
            }
        }

        // ─── Stage 7: Apply / Destroy ───────────────────────────────────────
        stage('Terraform Apply') {
            when {
                expression { return params.ACTION != 'plan' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    sh 'terraform apply -auto-approve -no-color tfplan'
                }
            }
        }

        // ─── Stage 8: Capture Terraform Outputs ─────────────────────────────
        stage('Capture Outputs') {
            when {
                expression { return params.ACTION == 'apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    script {
                        // Capture all outputs needed for app deployment
                        env.ECR_URL      = sh(script: 'terraform output -raw ecr_repository_url', returnStdout: true).trim()
                        env.ECS_CLUSTER  = sh(script: 'terraform output -raw ecs_cluster_name', returnStdout: true).trim()
                        env.ECS_SERVICE  = sh(script: 'terraform output -raw ecs_service_name', returnStdout: true).trim()
                        env.APP_BUCKET   = sh(script: 'terraform output -raw app_bucket_name', returnStdout: true).trim()
                        env.CF_DOMAIN    = sh(script: 'terraform output -raw cloudfront_domain_name', returnStdout: true).trim()
                        env.DEPLOY_REGION = sh(script: 'terraform output -raw primary_region', returnStdout: true).trim()

                        echo """
                        ┌──────────────────────────────────────────────────┐
                        │  Terraform Outputs                              │
                        ├──────────────────────────────────────────────────┤
                        │  ECR:        ${env.ECR_URL}
                        │  ECS:        ${env.ECS_CLUSTER} / ${env.ECS_SERVICE}
                        │  S3 Bucket:  ${env.APP_BUCKET}
                        │  CloudFront: ${env.CF_DOMAIN}
                        │  Region:     ${env.DEPLOY_REGION}
                        └──────────────────────────────────────────────────┘
                        """
                    }
                }
            }
        }

        // =====================================================================
        //  PHASE 2: APPLICATION DEPLOYMENT
        // =====================================================================

        // ─── Stage 9: Build & Push Backend Docker Image ─────────────────────
        stage('Backend: Docker Build & Push') {
            when {
                expression {
                    return params.ACTION == 'apply' && params.DEPLOY_APP
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    script {
                        def buildTag = "${env.ECR_URL}:${env.BUILD_NUMBER}"
                        def latestTag = "${env.ECR_URL}:latest"

                        echo "🐳 Building Docker image for banking backend..."

                        // Login to ECR
                        sh """
                            aws ecr get-login-password --region ${env.DEPLOY_REGION} | \
                            docker login --username AWS --password-stdin ${env.ECR_URL}
                        """

                        // Build with build number tag for traceability
                        dir('app/backend') {
                            sh """
                                docker build \
                                    --build-arg BUILD_NUMBER=${env.BUILD_NUMBER} \
                                    --build-arg ENVIRONMENT=${params.ENVIRONMENT} \
                                    -t banking-app:${env.BUILD_NUMBER} .
                            """
                        }

                        // Tag and push both :build-number and :latest
                        sh """
                            docker tag banking-app:${env.BUILD_NUMBER} ${buildTag}
                            docker tag banking-app:${env.BUILD_NUMBER} ${latestTag}
                            docker push ${buildTag}
                            docker push ${latestTag}
                        """

                        echo "✅ Docker image pushed: ${buildTag}"
                    }
                }
            }
        }

        // ─── Stage 10: Deploy Backend to ECS ────────────────────────────────
        stage('Backend: ECS Deploy') {
            when {
                expression {
                    return params.ACTION == 'apply' && params.DEPLOY_APP
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    script {
                        echo "🚀 Deploying backend to ECS Fargate..."

                        // Force new deployment to pull the latest image
                        sh """
                            aws ecs update-service \
                                --cluster ${env.ECS_CLUSTER} \
                                --service ${env.ECS_SERVICE} \
                                --force-new-deployment \
                                --region ${env.DEPLOY_REGION} \
                                --no-cli-pager
                        """

                        // Wait for service to stabilize
                        echo "⏳ Waiting for ECS service to stabilize (this may take 2-5 minutes)..."
                        sh """
                            aws ecs wait services-stable \
                                --cluster ${env.ECS_CLUSTER} \
                                --services ${env.ECS_SERVICE} \
                                --region ${env.DEPLOY_REGION}
                        """

                        echo "✅ Backend deployed and running on ECS!"
                    }
                }
            }
        }

        // ─── Stage 11: Deploy Frontend to S3 + CloudFront ───────────────────
        stage('Frontend: S3 + CloudFront') {
            when {
                expression {
                    return params.ACTION == 'apply' && params.DEPLOY_APP
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    script {
                        echo "📦 Uploading frontend to S3..."

                        // Sync frontend files to S3
                        sh """
                            aws s3 sync app/frontend/ s3://${env.APP_BUCKET}/frontend/ \
                                --delete \
                                --cache-control "public, max-age=3600" \
                                --region ${env.DEPLOY_REGION}
                        """

                        // Invalidate CloudFront cache
                        echo "🔄 Invalidating CloudFront cache..."
                        def cfDistId = sh(
                            script: """
                                aws cloudfront list-distributions \
                                    --query "DistributionList.Items[?DomainName=='${env.CF_DOMAIN}'].Id" \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        if (cfDistId && cfDistId != 'None') {
                            sh """
                                aws cloudfront create-invalidation \
                                    --distribution-id ${cfDistId} \
                                    --paths "/frontend/*" "/*"
                            """
                            echo "✅ CloudFront invalidation created for distribution: ${cfDistId}"
                        } else {
                            echo "⚠️  CloudFront distribution not found, skipping invalidation"
                        }

                        echo "✅ Frontend deployed to s3://${env.APP_BUCKET}/frontend/"
                    }
                }
            }
        }

        // ─── Stage 12: Database Init (first-time only) ──────────────────────
        stage('Database: Schema Init') {
            when {
                expression {
                    return params.ACTION == 'apply' && params.INIT_DB
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

                    script {
                        def dbEndpoint = sh(
                            script: 'terraform output -raw rds_cluster_endpoint',
                            returnStdout: true
                        ).trim()

                        echo """
                        ┌──────────────────────────────────────────────────────────┐
                        │  🗄️  Database Init Required                             │
                        ├──────────────────────────────────────────────────────────┤
                        │  RDS Endpoint: ${dbEndpoint}                             │
                        │                                                          │
                        │  SSH into the bastion host and run:                       │
                        │                                                          │
                        │  psql -h ${dbEndpoint} \\                                │
                        │       -U dbadmin -d appdb \\                              │
                        │       -f app/db/init.sql                                 │
                        │                                                          │
                        │  Or use SSM Session Manager:                              │
                        │  aws ssm start-session --target <bastion-instance-id>    │
                        └──────────────────────────────────────────────────────────┘
                        """

                        // If bastion has SSM agent, try running the init automatically
                        echo "📋 Database schema file (app/db/init.sql) is ready to apply."
                        echo "⚠️  Since RDS is in a private subnet, you need bastion access to run the SQL."
                    }
                }
            }
        }

        // ─── Stage 13: Deployment Summary ───────────────────────────────────
        stage('Deployment Summary') {
            when {
                expression {
                    return params.ACTION == 'apply' && params.DEPLOY_APP
                }
            }
            steps {
                script {
                    echo """
                    ╔══════════════════════════════════════════════════════════╗
                    ║  🎉  DEPLOYMENT COMPLETE — ${params.ENVIRONMENT.toUpperCase()}                          ║
                    ╠══════════════════════════════════════════════════════════╣
                    ║                                                          ║
                    ║  Frontend:  https://${env.CF_DOMAIN}/frontend/            ║
                    ║  API:       https://${env.CF_DOMAIN}/api/                 ║
                    ║  Health:    https://${env.CF_DOMAIN}/api/health            ║
                    ║                                                          ║
                    ║  Build:     #${env.BUILD_NUMBER}                          ║
                    ║  Image:     ${env.ECR_URL}:${env.BUILD_NUMBER}            ║
                    ║  ECS:       ${env.ECS_CLUSTER} / ${env.ECS_SERVICE}       ║
                    ║  S3:        s3://${env.APP_BUCKET}/frontend/              ║
                    ║                                                          ║
                    ╚══════════════════════════════════════════════════════════╝
                    """
                }
            }
        }
    }

    post {
        always {
            // Clean up plan files and Docker images
            sh 'rm -f tfplan tfplan.txt'
            sh "docker rmi banking-app:${env.BUILD_NUMBER} || true"
            cleanWs()
        }
        success {
            script {
                def emoji = params.ACTION == 'destroy' ? '🗑️' : '✅'
                def appMsg = params.DEPLOY_APP ? ' + App deployed' : ''
                echo "${emoji} Terraform ${params.ACTION} succeeded for ${params.ENVIRONMENT}${appMsg}"

                // Uncomment to enable Slack notifications:
                // slackSend(
                //     channel: '#infra-deployments',
                //     color: 'good',
                //     message: "${emoji} *${params.ENVIRONMENT.toUpperCase()}* — Terraform ${params.ACTION} succeeded${appMsg}\n" +
                //              "Build: ${env.BUILD_URL}\n" +
                //              (params.DEPLOY_APP ? "Frontend: https://${env.CF_DOMAIN}/frontend/\n" : '') +
                //              "Triggered by: ${currentBuild.getBuildCauses()[0].shortDescription}"
                // )
            }
        }
        failure {
            script {
                echo "❌ Terraform ${params.ACTION} failed for ${params.ENVIRONMENT}"

                // Uncomment to enable Slack notifications:
                // slackSend(
                //     channel: '#infra-deployments',
                //     color: 'danger',
                //     message: "❌ *${params.ENVIRONMENT.toUpperCase()}* — Terraform ${params.ACTION} FAILED\n" +
                //              "Build: ${env.BUILD_URL}\n" +
                //              "Triggered by: ${currentBuild.getBuildCauses()[0].shortDescription}"
                // )
            }
        }
    }
}
