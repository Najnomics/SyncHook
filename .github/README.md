# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the SyncHook project's CI/CD pipeline.

## Workflows Overview

### 🔄 CI (`ci.yml`)
**Triggers:** Push to main/develop, Pull Requests
**Purpose:** Continuous Integration testing

- **Test**: Runs all unit, integration, and fuzz tests
- **Lint**: Checks code formatting and common issues
- **Security**: Runs security analysis with Slither and Mythril
- **Gas Optimization**: Analyzes gas usage patterns
- **Coverage**: Generates test coverage reports

### 🚀 Deploy (`deploy.yml`)
**Triggers:** Tags, Manual dispatch
**Purpose:** Automated deployment to different environments

- **Staging**: Deploys to Sepolia testnet
- **Production**: Deploys to Mainnet
- **Notifications**: Sends alerts to Slack/Discord

### 🔒 Security Audit (`security-audit.yml`)
**Triggers:** Weekly schedule, Push to main, Manual dispatch
**Purpose:** Comprehensive security analysis

- **Security Scan**: Runs Slither, Mythril, and Semgrep
- **Dependency Check**: Audits for vulnerable dependencies
- **Code Quality**: Checks for security anti-patterns
- **Report Generation**: Creates detailed security reports

### 🧪 Fuzz Testing (`fuzz-testing.yml`)
**Triggers:** Daily schedule, Push to main/develop, Manual dispatch
**Purpose:** Extensive fuzz testing

- **Fuzz Tests**: Runs 10,000 fuzz iterations per test suite
- **Invariant Tests**: Tests system invariants
- **Performance Testing**: Measures gas usage and execution time
- **Analysis**: Generates detailed fuzz analysis reports

### 📦 Release (`release.yml`)
**Triggers:** Version tags, Manual dispatch
**Purpose:** Automated release management

- **Release Creation**: Creates GitHub releases
- **Artifact Building**: Generates deployment artifacts
- **Contract Deployment**: Deploys to production networks
- **Notifications**: Announces releases

### 🔄 Dependency Update (`dependency-update.yml`)
**Triggers:** Weekly schedule, Manual dispatch
**Purpose:** Automated dependency management

- **Update Check**: Scans for outdated dependencies
- **Security Audit**: Checks for vulnerabilities
- **Auto-Update**: Creates PRs for safe updates

### 📊 Benchmark (`benchmark.yml`)
**Triggers:** Daily schedule, Push to main, Manual dispatch
**Purpose:** Performance monitoring

- **Gas Benchmark**: Tracks gas usage over time
- **Performance Benchmark**: Measures execution times
- **Regression Detection**: Identifies performance regressions

## Issue Templates

### 🐛 Bug Report (`ISSUE_TEMPLATE/bug_report.md`)
Standardized template for bug reports with smart contract context.

### ✨ Feature Request (`ISSUE_TEMPLATE/feature_request.md`)
Template for feature requests with implementation complexity assessment.

### 🔒 Security Vulnerability (`ISSUE_TEMPLATE/security_vulnerability.md`)
Template for security vulnerability reports with responsible disclosure.

## Pull Request Template

Standardized PR template (`pull_request_template.md`) with:
- Smart contract change tracking
- Security considerations
- Gas impact assessment
- Comprehensive checklist

## Configuration Files

### 👥 Code Owners (`CODEOWNERS`)
Defines code ownership by team:
- `@synchook/core-team`: Global owners
- `@synchook/smart-contracts-team`: Solidity code
- `@synchook/backend-team`: Go services
- `@synchook/frontend-team`: Frontend code
- `@synchook/devops-team`: Infrastructure
- `@synchook/security-team`: Security-related files

### 🤖 Dependabot (`dependabot.yml`)
Automated dependency updates for:
- npm packages
- GitHub Actions
- Docker images
- Go modules

## Environment Variables

The workflows require the following secrets to be configured:

### Required Secrets
- `PRIVATE_KEY`: Private key for contract deployment
- `MAINNET_RPC_URL`: Mainnet RPC endpoint
- `SEPOLIA_RPC_URL`: Sepolia testnet RPC endpoint
- `ETHERSCAN_API_KEY`: Etherscan API key for verification

### Optional Secrets
- `SLACK_WEBHOOK`: Slack notifications
- `DISCORD_WEBHOOK`: Discord notifications
- `TWITTER_API_KEY`: Twitter notifications
- `TWITTER_API_SECRET`: Twitter API secret
- `TWITTER_ACCESS_TOKEN`: Twitter access token
- `TWITTER_ACCESS_TOKEN_SECRET`: Twitter access token secret

## Usage

### Running Workflows Manually
Most workflows support manual dispatch:
1. Go to Actions tab in GitHub
2. Select the workflow
3. Click "Run workflow"
4. Choose parameters and run

### Monitoring Workflows
- Check the Actions tab for workflow status
- Review artifacts for detailed reports
- Monitor notifications for deployment status

### Customizing Workflows
- Modify workflow files in `.github/workflows/`
- Update issue templates in `.github/ISSUE_TEMPLATE/`
- Adjust code ownership in `CODEOWNERS`
- Configure dependency updates in `dependabot.yml`

## Best Practices

1. **Security**: Never commit private keys or sensitive data
2. **Testing**: Always run tests before merging
3. **Documentation**: Update documentation with changes
4. **Reviews**: Require reviews for critical changes
5. **Monitoring**: Monitor workflow failures and performance

## Troubleshooting

### Common Issues
- **Test Failures**: Check test logs for specific errors
- **Deployment Issues**: Verify RPC URLs and private keys
- **Security Warnings**: Review and address security findings
- **Performance Regressions**: Compare benchmark results

### Getting Help
- Check workflow logs in the Actions tab
- Review generated reports and artifacts
- Contact the development team for assistance
