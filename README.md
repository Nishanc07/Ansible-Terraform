# 🚀 Azure VM Provisioning & SonarQube Deployment with Terraform and Ansible

This project automates the provisioning of Azure Virtual Machines using **Terraform** and configures them using **Ansible** to install Docker and deploy **SonarQube** inside a Docker container.

---

## 📋 Features

- **Infrastructure Provisioning (Terraform):**

  - Azure Resource Group, Virtual Network, Subnet
  - Public IPs and Network Interfaces
  - Ubuntu Linux Virtual Machines
  - Network Security Groups (NSG) with SSH (22) and SonarQube (9000) ports open

- **Configuration Management (Ansible):**
  - Installs Docker and Docker Compose
  - Deploys SonarQube as a Docker container
  - Sets up SSH key-based access

---

## 🛠 Prerequisites

- An active [Azure account](https://portal.azure.com/)
- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed
- Azure CLI authenticated (`az login`)

## 🚦 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Nishanc07/Ansible-Terraform.git
cd Ansible-Terraform
```

## 2. Initialize Terraform

```bash
terraform init
terraform apply --auto-approve
terraform output

```

## 3. Copy public ip from the output and add it to your inventory file

## Run this command. Ansible will install Docker and set up SonarQube automatically:

```bash
ansible-playbook -i inventory playbook.yaml


```

# This project demonstrates how to use Terraform for provisioning Azure infrastructure and Ansible for

# configuration management.The combination of Terraform for infrastructure as code (IaC) and Ansible for configuration

# management provides a powerful way to automate and manage cloud resources effectively.
# Ansible-Terraform
