# Deployment Guide

This guide provides step-by-step instructions to deploy and manage an EKS cluster, NGINX web application, monitoring stack, ingress configuration, and database setup on Kubernetes. It includes the use of Terraform, Helm charts, GitHub Actions, and best practices for each component.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [EKS Cluster Deployment](#eks-cluster-deployment)
3. [NGINX Application Setup](#nginx-application-setup)
4. [Monitoring with Prometheus and Grafana](#monitoring-with-prometheus-and-grafana)
5. [HAProxy Ingress Configuration](#haproxy-ingress-configuration)
6. [Database Setup](#database-setup)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Folder Structure](#folder-structure)
9. [Troubleshooting Index](#troubleshooting-index)
10. [Challenges](#challenges)
---

## Prerequisites

- AWS account with IAM permissions for EKS and related resources.
- Terraform installed on your local machine.
- kubectl and helm installed on your local machine.
- AWS CLI configured with appropriate credentials.
- Basic knowledge of Kubernetes, Terraform, and Helm.
- Github account and github cli installed your local machine.

---

## EKS Cluster Deployment

1. Navigate to the `terraform/` directory:
   ```bash
   cd terraform
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the resources being created including the iam policy and roles.
    ```bash
    terraform plan
    ```
    **Please note**:
    As these roles and policy will be needed to access and manage your nodes and the github action role is required for your cicd workflow to create and apply the nginx deployment later in this docs.

4. Apply the Terraform configuration to create the EKS cluster:
   ```bash
   terraform apply
   ```

5. Update your kubeconfig to interact with the new cluster:
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```

6. Verify the cluster is up and running:
   ```bash
   kubectl get nodes
   ```
    **Please note**: if you encounter any issues such as permissions when trying to run any kubectl commands see the troubleshooting section.
---
## NGINX Application Setup

### Deployment and Service

1. Apply the NGINX Deployment and Service:
   ```bash
   kubectl apply -f kubernetes/nginx-deployment.yaml
   ```
   The nginx namespace along with the nginx deployment services will be deployed.

2. Verify the deployment:
   ```bash
   kubectl get pods -n nginx
   kubectl get svc -n nginx
   ```
    **Please note**: this becomes an automataed workflow each time you push a change to the nginx configurations.

### Configuration Highlights

- **Metrics Exporter**: The NGINX Prometheus exporter is included as a sidecar container.
- **Environment Variables**: Database connection details (e.g., `DB_HOST`, `DB_USER`, `DB_PASSWORD`) are set as environment variables.

---

## Monitoring with Prometheus and Grafana

### Prometheus Setup

1. Install Prometheus using Helm:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm upgrade --install prometheus prometheus-community/prometheus \
                --namespace monitoring \
                --create-namespace \
                --values kubernetes/monitoring/prometheus-values.yaml
   ```

2. Verify the Prometheus installation:
   ```bash
   kubectl get pods -n monitoring
   kubectl get svc -n monitoring
   ```

3. Once Prometheus has installed, you can run enable port forwarding to access via locally:
    ```bash
    kubectl port-forward -n monitoring svc/prometheus-server 9090:80
    ```
4. Or via the external IP of prometheus-server found via:
    ```bash
    kubectl get -n monitoring svc
    ```

### Grafana Setup

1. Install Grafana using Helm:
   ```bash
   helm repo add grafana https://grafana.github.io/helm-charts
   helm install grafana grafana/grafana --namespace monitoring --set adminPassword=admin --set service.type=LoadBalancer
   ```

2. Access Grafana:
   Retrieve the LoadBalancer IP and open it in your browser.

   ```bash
   kubectl get svc -n monitoring
   ```

3. Add Prometheus as a data source in Grafana using its ClusterIP or external URL.
    ```bash
    kubectl g -n monitoring svc
    ```
    **Please note**: take the EXTERNAL-IP from prometheus-server

4. Import or create dashboards for NGINX metrics (CPU, memory, request rates, etc.).


---

## HAProxy Ingress Configuration

1. Install HAProxy using Helm:
   ```bash
   helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
   helm install haproxy-ingress haproxy-ingress/kubernetes-ingress --namespace haproxy-ingress --create-namespace
   ```

2. Apply TCP and UDP services for HAProxy:
   ```bash
   kubectl apply -f kubernetes/haproxy-ingress-tcp.yaml
   kubectl apply -f kubernetes/haproxy-ingress-udp.yaml
   ```

3. Verify the LoadBalancer services:
   ```bash
   kubectl get svc -n haproxy-ingress
   ```

4. Create an Ingress resource for the NGINX application:
   ```bash
   kubectl apply -f kubernetes/nginx-ingress.yaml
   ```

---

## Database Setup

1. Deploy MySQL using Helm:
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm install mysql bitnami/mysql --namespace nginx --set auth.rootPassword=rootpassword --set auth.database=mydatabase
   ```

2. Verify the MySQL service:
   ```bash
   kubectl get pods -n nginx
   kubectl get svc -n nginx
   ```

3. Connect the NGINX application to MySQL using environment variables:
   Update `DB_HOST`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` in the deployment file.

4. Verify MySQL database is connected to the NGINX Application:
    Create a debug pod(deploy debug-pod.yaml) with mysql installed and exec/connect to it to test
    
    ```bash
    kubectl apply -f debug-pod.yaml #wait a few minutes for the pod to deploy
    kubectl exec -it debug-pod -n nginx -- /bin/bash
    mysql -h mysql.nginx.svc.cluster.local -u root -p
    mysql> SHOW DATABASES;
    +--------------------+
    | Database           |
    +--------------------+
    | information_schema |
    | mydatabase         |
    | mysql              |
    | performance_schema |
    | sys                |
    +--------------------+
    5 rows in set (0.01 sec)
    5 rows in set (0.01 sec)

    mysql> USE mydatabase;
    Database changed
    mysql> show tables;
    Empty set (0.00 sec)
    ```
---

## CI/CD Pipeline

### GitHub Actions Workflows

1. **NGINX Deployment Workflow**: Automates deployment of NGINX.
2. **Prometheus and Grafana Workflow**: Automates monitoring stack setup.
3. **HAProxy Workflow**: Automates ingress controller setup.
4. **Database Workflow**: Automates MySQL setup and schema initialization.

Refer to the `.github/workflows/` directory for detailed configurations.

Ensure you have followed:
https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

https://github.com/aws-actions/configure-aws-credentials

In setting up your OIDC to allow your github action workflows to work properly with AWS.

---

## Folder Structure

```plaintext
project-root/
├── .github/
│   └── workflows/
│       ├── deploy-database.yaml
│       ├── deploy-ingress.yaml
│       ├── deploy-monitoring.yaml
│       └── deploy_nginx.yaml
├── helm/
│   └── monitoring/
│       ├── prometheus-values.yaml
│       └── grafana-values.yaml
├── kubernetes/
│   ├── database/
│   │   ├── mysql-deployment.yaml
│   │   └── mysql-service.yaml
│   ├── ingress/
│   │   ├── haproxy-ingress-tcp.yaml
│   │   └── haproxy-ingress-udp.yaml
│   └── nginx/
│   │   ├── nginx-deployment.yaml
│   │   └── nginx-ingress.yaml
├── terraform/
│   ├── main.tf
│   ├── iam.tf
│   ├── providers.tf
│   └── vars.tf
└── README.md        
```

---

## Troubleshooting Appendix

### Prometheus Pending Pods Issue

**Problem**: Prometheus pods are stuck in a `Pending` state.

**Root Causes**:
1. PersistentVolumeClaims (PVCs) are unbound due to:
   - Missing or incorrect `storageClassName`.
   - Lack of available PersistentVolumes (PVs).
2. Insufficient cluster resources for scheduling.

**Solutions**:
1. **Validate PVC Configuration**:
   - Ensure the `prometheus-values.yaml` file includes a valid storage class.
   ```yaml
   server:
     persistentVolume:
       enabled: true
       size: 8Gi
       storageClass: gp2
   ```

2. **Manually Provision a PV** (if dynamic provisioning is unavailable):
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: prometheus-pv
   spec:
     capacity:
       storage: 8Gi
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: gp2
     hostPath:
       path: /mnt/data
   ```

3. **Increase Cluster Capacity**:
   - Add more nodes or scale up existing nodes or update main.tf to create more nodes:
     ```bash
     kubectl scale node <node-name> --replicas=<desired-count>
     ```

4. **Delete and Redeploy Pods**:
   - Remove existing pods to trigger a new scheduling cycle:
     ```bash
     kubectl delete pod -l app=prometheus -n monitoring
     ```

5. **Monitor Resource Utilization**:
   - Check for memory or CPU bottlenecks:
     ```bash
     kubectl top pods -n monitoring
     ```

By addressing these issues, the Prometheus setup can recover and function as expected.

### GitHub Actions IAM Role Issue/OIDC

**Problem**: Problem: The IAM role configured for GitHub Actions fails to perform Kubernetes operations, resulting in errors such as Forbidden or Unauthorized.

**Root Causes**:
1. The IAM role is not properly mapped in the EKS aws-auth ConfigMap.
2. Missing or insufficient RBAC permissions for the IAM role.

**Solutions**:
### 1. Map the IAM Role in `aws-auth` ConfigMap

To enable the IAM role to interact with the Kubernetes cluster:

- **Retrieve the ARN of the IAM role** created for GitHub Actions.
- **Update the `aws-auth` ConfigMap** in the `kube-system` namespace to map the IAM role to a Kubernetes group with administrative or required permissions.

    #### Example `aws-auth.yaml`:

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
    name: aws-auth
    namespace: kube-system
    data:
    mapRoles: |
        - rolearn: arn:aws:iam::<your-account-id>:role/github-actions-role
        username: github-actions
        groups:
            - system:masters
    ```

    - Apply the changes to the cluster:

    ```bash
    kubectl apply -f aws-auth.yaml
    ```



### 2. Create a ClusterRole and ClusterRoleBinding

Define an RBAC policy to allow the IAM role to perform necessary Kubernetes operations.

#### Example `rbac-clusterrolebinding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: github-actions-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "deployments", "nodes"]
  verbs: ["get", "list", "watch", "create", "delete", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: github-actions-role-binding
subjects:
- kind: User
  name: github-actions
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: github-actions-role
  apiGroup: rbac.authorization.k8s.io
```

- Apply the RBAC configurations:

   ```bash
   kubectl apply -f rbac-clusterrolebinding.yaml
   ```



### 3. Verify Role Access

Test the setup by running a simple command in the GitHub Actions workflow to verify that the role has appropriate access.

#### Example Test Step in GitHub Actions Workflow:

```yaml
- name: Test Kubernetes Access
  run: kubectl get pods -A
```

If the setup is correct, the IAM role will successfully perform Kubernetes operations without errors.



By following these steps, the GitHub Actions IAM role will have the necessary permissions to interact with the Kubernetes cluster, ensuring a seamless CI/CD process.


## Challenges

### GitHub Actions IAM Role Issue

The kubectl get nodes command weren't working and would receive errors such as "You must be logged in to the server (Unauthorized) " and updating the kubeconfig made no change. The solution and troubleshooting steps for this is in the troubleshooting index.

Additionally the OIDC in the github actions also had this issue:
`Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`

Where none of these solutions related to it worked as it looked like a misconfiguration:
https://github.com/aws-actions/configure-aws-credentials/issues/318
https://github.com/aws-actions/configure-aws-credentials/issues/1137
https://github.com/aws-actions/configure-aws-credentials/issues/1238

The solution for this issues after was just deleting and creating the OIDC in the AWS console.

### Prometheus Deployment Issue

Another challenge faced was the initial prometheus deployment had the server pod stuck in pending.From further investigation there were no nodes available and another error in the logs mentioned it could not find a proper storage/volume. I manually created the EBS CSI Driver and iam role (both the ebs driver and role can be provisioned and managed in terraform) along with the troubleshooting steps to resolve this issue which can also be found in the index.

## Conclusion

This guide provides a comprehensive setup for deploying, monitoring, and exposing an NGINX web application on Kubernetes. Tailor the configurations as needed to suit your production or personal environment.
