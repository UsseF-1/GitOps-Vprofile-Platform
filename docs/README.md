# docs/

This folder contains supplementary documentation and screenshots.

## Screenshots

Place the following screenshots here after running the project:

| File | When to capture |
|---|---|
| `screenshots/terraform-plan-output.png` | After the staging branch workflow runs its plan |
| `screenshots/sonar-quality-gate.png` | After SonarCloud analysis completes |
| `screenshots/ecr-image-tags.png` | After a successful BUILD_AND_PUBLISH job |
| `screenshots/eks-pods-running.png` | After `kubectl get pods -n default` shows Running |
| `screenshots/vprofile-app-login.png` | After accessing the app in a browser |
| `screenshots/github-actions-all-jobs.png` | The complete workflow showing all 3 green jobs |

## Architecture Diagrams

- `architecture/gitops-flow.png` — Full GitOps workflow diagram
- `architecture/network-diagram.png` — AWS VPC/EKS network topology
- `architecture/cicd-pipeline.png` — Application CI/CD pipeline stages
