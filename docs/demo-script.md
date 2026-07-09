# Demo Script

## Opening

This lab demonstrates end-to-end DevSecOps on AWS: source control, infrastructure as code, container build and scan, Kubernetes deployment, application persistence to MongoDB, and cloud-native detection of intentional misconfigurations.

## Key proof points

1. GitHub is the system of record for code, Terraform, Kubernetes manifests, and pipelines.
2. Terraform deploys the AWS foundation: VPC, private EKS, EC2 MongoDB, public S3 backups, ECR, AWS Config, GuardDuty, and EKS audit logging.
3. The app pipeline builds a custom image, scans it, pushes it to ECR, and deploys it to Kubernetes.
4. The web application writes and reads data from MongoDB.
5. The running container contains `/app/wizexercise.txt` with `Vamshidhar’s Seetha`.
6. Intentional weaknesses are visible and detectable through AWS-native security tooling.

## Live commands

```bash
aws eks update-kubeconfig --region <region> --name <cluster>
kubectl get nodes -o wide
kubectl -n wiz-lab get deploy,pod,svc,ingress
kubectl -n ingress-nginx get svc ingress-nginx-controller
kubectl -n wiz-lab exec deploy/wiz-todo -- cat /app/wizexercise.txt
kubectl -n wiz-lab auth can-i '*' '*' --as=system:serviceaccount:wiz-lab:wiz-todo-sa
aws configservice describe-compliance-by-config-rule --region <region>
aws eks describe-cluster --region <region> --name <cluster> --query 'cluster.logging'
```

## Remediation close

For production, the target state is no public SSH, private S3 backups, least-privilege IAM, supported OS/database versions, namespace-scoped Kubernetes RBAC, secrets externalization, admission controls, WAF/TLS on ingress, and automated policy enforcement in CI/CD.
