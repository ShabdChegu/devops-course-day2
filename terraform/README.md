# terraform/ — Infrastructure as Code (IaC) with Azure & Rover

This folder provisions **server2** (an Ubuntu Linux VM in Azure `centralindia`) along with all supporting network topology (VNet, Subnet, Public IP, NSG) and generates a local SSH key pair (`server2_key.pem`).

Just like `jenkins/` and `signoz/`, both **Terraform** and the **Rover visualizer** run strictly inside Docker — nothing needs to be installed on your host machine.

| File | Role |
|---|---|
| `docker-compose.yml` | Standalone runner for Terraform CLI (`terraform`) and the Rover web UI (`rover`) |
| `versions.tf` | Required Terraform core (>= 1.8.0) and pinned `azurerm`, `tls`, `local` providers |
| `variables.tf` | Configurable variables: VM name (`server2`), size (`Standard_D2s_v3`), region (`centralindia`), etc. |
| `main.tf` | Azure infrastructure declarations: RG, VNet, Subnet, NSG (SSH + port 8000), NIC, Public IP, and VM |
| `outputs.tf` | Public IP address, VM name, and the direct SSH login command |
| `../docs/11-terraform.md` | In-depth chapter guide, architecture diagram, pitfalls, and quiz |

---

## 1. Quick Start

Ensure your Azure credentials are in the root `.env` file (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`).

From the repo root:

```bash
# 1. Initialize Terraform provider plugins
make tf-init

# 2. Preview the resources to be created
make tf-plan

# 3. Create the VM and networking in Azure
make tf-apply

# 4. (Optional) Launch the visual architecture graph UI
make up-rover
# Open http://localhost:9000
```

---

## 2. Connect to the Azure VM

Once `make tf-apply` finishes:

1. View outputs and connection string:
   ```bash
   make tf-output
   ```

2. SSH directly into the VM:
   ```bash
   ssh -i terraform/server2_key.pem azureuser@<PUBLIC_IP>
   ```

3. Inside the VM, you can verify its hardware specs:
   ```bash
   uname -a
   lscpu | grep "CPU(s):"
   free -h
   ```
   *(You will see 2 vCPUs and 8GB RAM as configured by `Standard_D2s_v3`)*.

---

## 3. Stop or Clean Up

- **Stop the Rover web UI:**
  ```bash
  make down-rover
  ```

- **Destroy all Azure resources:**
  ```bash
  make tf-destroy
  ```
  *This automatically cleans up the VM, disks, public IP, and network interface so you do not incur unwanted cloud charges.*

