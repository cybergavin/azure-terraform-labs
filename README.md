# Azure Terraform Labs (az-tfl)

- Intended for quick evaluation of Azure services
- Easy and quick creation and deletion
- Parameterized deployments requiring only changes to terraform.tfvars (set variable values)
- Opinionated deployments with cost optimization (use resource SKUs as required)
- Each lab is self-contained within a folder at this level

## DOs
- Ensure that you read the README.md for each lab to understand the resources created and configuration (e.g. IP addresses).
- Authenticate with Azure (e.g. Azure CLI or extend the Terraform code) prior to executing each lab.
- Ensure that your account has adequate privileges on a subscription to create resources.
- Destroy your resources after you've completed your tests/demos in order to minimize costs.

## DON'Ts
- Store credentials in plain-text and share them. For the purpose of these labs, credentials are stored in plain-text with the asumption that these labs are private.

## TIP
- Ideally, if you have an empty/test/lab subscription with Contributor role, you can safely run these labs.