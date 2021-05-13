# Secure REDCap on Azure

This repo will deploy REDCap using Terraform. The terraform configuration will provision all the infrastructure with all the necessary security controls in place. You will need to establish a vnet peering from the hub virtual network back to this REDCap virtual network and deploy source code to get the app up and running. From there, you will need to run the Ansible playbook (inventory file gets generated as part of this deployment) to configure WVD session hosts.

This repo does not include any REDCap shared services such as Azure FrontDoor or SendGrid. That needs to be managed from a separate repository.

## Pre-requisites

Before you begin, make sure you have the following:

- Hub/Spoke network topology.
    - The hub virtual network will need to have a firewall in place.
    - If your Active Directory Domain Controller or Azure AD Domain Services is in another spoke network, you'll need to have routes in place to ensure transitive networking is enabled from the REDCap spoke networks and the AD servers.

- Azure Storage Account or Terraform Cloud to store your remote state files. 

    > Once you have these in place, update the `backend.tf` file to include your backend.

- REDCap zip file that will be accessible to Azure App Service for code deployment.

    > If it is stored in Azure Storage, you'll need a SAS token.

- Virtual Network address allocation for the REDCap resources and divided into Subnets. Here are the minimum CIDR ranges you'll need:
    
    > The deployment relies on the subnet names listed below. If you decide to change these, make sure you replace all instances in `main.tf`.

    - `/25` for the virtual network
    - `/27` for `PrivateLinkSubnet`
    - `/27` for `ComputeSubnet`
    - `/26` for `IntegrationSubnet` 

- DNS IP address(es).
- Firewall IP address.

    > Make sure your firewall is configured to allow traffic to pass from and to the REDCap virtual networks.

- VNET Peering information.
    
    > Terraform will perform the one-way peer from REDCap to your hub virtual network

- Route table routes.
    
    > Hub/Spoke topology means you may be relying on resources that are deployed in another spoke virtual network. If resources are in a spoke, you'll need to send the traffic to the firewall in the hub for spoke-to-spoke transit networking. 

## Naming conventions

The resources provisioned using this repo will be named using the naming conventions as outlined in the Cloud Adoption Framework. See this [link](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) for more info

## Workspaces

In order to maintain multiple REDCap deployments with this repo, a decision was made to manage each deployment config using .tfvars files and terraform workspaces. Terraform workspaces will allow you to keep all deployment state information in a single storage account but logically separated using workspaces. With each deployment, you'll need to ensure you are selecting the right workspace and using the right .tfvars file. This can get difficult to manage and there's a high possibility of human error.

The alternative would be to create branches for each deployment but managing code changes between branches can become cumbersome over time as well. 

## So, what get's deployed?

- Azure Monitor alerts to satisfy HIPAA compliance policies.
- Azure Virtual Network with service endpoints enabled for Key Vault, Storage, Sql, and Web and a subnet delegation for App Service Vnet integration.
    > Virtual network peering will also be made to hub (one way) but peer from hub to REDCap is not in scope here. Also, route table routes will be added to send traffic for internet and AD to the firewall but routes coming back to REDCap is not in scope here either. You will need to manage these in another repo or via Azure Portal.
- Azure Private DNS zones for blob, mysql, and keyvault.
    > The decision was made to deploy private DNS zones and linked to the REDCap virtual network as opposed to the hub virtual network which is more common. The reason for this was to reduce the network dependency (other than the hub peering) and not allow the REDCap resources to be resolvable within the rest of the network topology.
- Azure Storage Account with private endpoint and service endpoints enabled (general purpose) to store survey data.
- Azure Storage Account with private endpoint and service endpoints enabled (premium files) to mount as a shared drive in the secure workstation.
- Azure Key Vault with private endpoint and service endpoints enabled to store application secrets. Access policies will be configured for AppService to be able to read secrets.
- Azure Database for MySQL with private endpoint enabled and service endpoints.
- Azure App Service to host REDCap application. This service will be vnet integrated and have access restrictions in place to NOT allow any incoming traffic from any source except the ComputeSubnet (from secure workstation), IntegrationSubnet, or Azure FrontDoor. Client IP is also included for testing purposes.
- Azure Application Insights for monitoring
- Windows Virtual Desktop to provide secure computing environment to pull survey data and perform data analysis.
- Virtual Machines as WVD Session Hosts
    > The virtual machines will come with DependencyAgent, IaaSAntimalware, and WinRM (for Ansible) installed as VM Extensions
- Azure Recovery Services Vault with VM Backup Policy (will need to add Azure Files backup policy too)
    > The recovery policy will need to be standardized and/or variable-ized
- Ansible inventory file which you can use to run the `site.yml` playbook against

## Provisioning REDCap

1. Create a new `*.tfvars` file and drop into the `workspaces` directory
    > The name of your `*.tfvars` file and the `terraform workspace` will be the same

1. Execute the `terraform plan` and `terraform apply` commands and pass in your `*.tfvars` file in the `-var-file` parameter.
    > You will be required to enter the local vm username and password and the REDCap zip file URL.

1. After the resources have been provisioned, you'll need to create a vnet peering back from the hub vnet to the redcap vnet
    > This codebase will only apply one half of the peering (from redcap to hub)

1. Next, deploy the source code from the github repo
    > The command to deploy the source is in the `terraform output` as `deploy_source`

## Deleting REDCap

- If you have deployed a Recovery Services Vault, you'll need to make sure to stop and delete your VM and file share backups before running the `terraform destroy` command.
- Be sure to delete the vnet peering from the hub to the REDCap instance
- Be sure to delete the `terraform workspace`

## Azure DevOps Pipeline

This repo comes with an `azure-pipelines.yml` file. To use it, you'll need to setup a [Variable Group](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml) and add the following secrets. Ideally you will be storing these values in Azure Key Vault and using that to link secrets:

- `client-id` - used by terraform
- `client-secret` - used by terraform
- `tenant-id` - used by terraform
- `main-subscription-id` - this is the id of the subscription where your storage account where remote state file lives
- `local-vm-username`
- `local-vm-password`
- `domain-admin-username`
- `domain-admin-password`
- `domain-name`
- `domain-ou-path`
- `redcapzip`

You should also provision a small Linux VM in your REDCap shared services subscription and install the Azure DevOps Build Agent software on it. This way, you will be able to use your build machine to invoke the Ansible playbook against the new session host VMs using private IP addresses.

Lastly, add pipeline variables called `notifyUsers` and `workspace` that can be [set at queue time](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#allow-at-queue-time).
