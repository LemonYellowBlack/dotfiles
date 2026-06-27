---
name: deploy-docgen
description: Deploy DocGen services (ingestor/processor) to dev, qa, or prod via GitHub Actions
argument-hint: "[ingestor/processor/all] [dev/qa/prod]"
disable-model-invocation: true
allowed-tools: Bash(gh *)
---

Deploy a DocGen service to an environment via GitHub Actions workflow dispatch.

## Arguments: $ARGUMENTS

Expected format: `[service] [environment]`
- **service**: `ingestor`, `processor`, or `all`
- **environment**: `dev`, `qa`, or `prod`

## Workflow mapping

| Service | Workflow file |
|---------|--------------|
| ingestor | `domains-docgen-ingestor.yml` |
| processor | `domains-docgen-processor.yml` |

## Environment-to-branch mapping

The workflows are branch-gated — each environment's job only runs on its corresponding branch:

| Environment | Branch |
|-------------|--------|
| dev | `dev` |
| qa | `qa` |
| prod | `main` |

## Instructions

1. Parse the arguments to determine the service(s) and environment.
2. Map the environment to the correct git branch using the table above.
3. For each service to deploy, run: `gh workflow run <workflow-file> --ref <branch>`
4. After triggering, run `gh run list --workflow=<workflow-file> -L 1` to get the run ID.
5. Report the run URL so the user can monitor it.
6. If the user specified `all`, trigger both ingestor and processor in parallel.

## Safety

- For `prod` deployments, confirm with the user before triggering.
- Warn if the user is deploying to an environment and the corresponding branch may not have the latest changes.
