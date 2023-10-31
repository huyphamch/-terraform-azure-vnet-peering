## Description
The Rand Enterprises Corporation is evaluating Azure as a deployment platform. To help the company with its evaluation, you need to create virtual networks in the region specified by Rand Enterprises Corporation. You have to create test virtual machines in two virtual networks, establish connectivity between the two networks via VNet peering, and ensure connectivity is established properly.
<br />
To test the platform, Rand Enterprises Corporation wants to onboard an employee on the company’s default Azure Active Directory and assign a Custom RBAC role, under which they will be able to read the network and storage along with the VM. Under this custom RBAC, the employee should also be given permission to start and restart the VM. You have to onboard the employee under the default Azure AD and create a custom RBAC for the role of computer operator for this employee.
<br />
As a security measure, you need to ensure that the onboarded user can only access the resources mentioned in the custom role and adhere to the principle of least privilege.

## Objectives
To connect Internet workloads using Vnet peering and assign a custom role for operating these workloads.
Expected Deliverables:
- Identify the networks
- Workload deployed to these networks
- Establishing the connectivity between these networks
- Onboard a user
- Create and assign a custom role to the user.

## Usage
<br /> 1. Open terminal
<br /> 2. Before you can execute the terraform script, your need to configure your Azure environment first.
<br /> az login --user <myAlias@myCompany.onmicrosoft.com> --password <myPassword>
<br /> Update tenant_id in main.tf (az account tenant list)
<br /> Update subscription_id in main.tf (az account subscription list)
<br /> 3. Now you can apply the terraform changes.
<br /> terraform init
<br /> terraform apply --auto-approve
<br /> 4. Connect to public VM and ping the private VM.
<br /> Test result: Ping answer messages received.
<br /> 5. At the end you can cleanup the created AWS resources.
<br /> terraform destroy --auto-approve
