# ansible/ — Configuration as Code with Docker & Semaphore UI

This directory configures **server2** (the Azure VM created in Chapter 11) using **Ansible** and provides a web dashboard via **Ansible Semaphore**.

Whenever Terraform spins up a fresh VM, that VM has a clean OS with no Docker, no Docker Compose, and no application dependencies. Ansible bridges that gap by declaratively configuring the server over SSH.

Just like `jenkins/`, `signoz/`, and `terraform/`, both the **Ansible CLI runner** and the **Semaphore Web UI** run strictly inside Docker — no local Python packages or host tools are required.

| File / Folder | Role |
|---|---|
| `docker-compose.yml` | Containerized runner for Ansible CLI (`ansible`, `ansible-playbook`) and Semaphore UI (`http://localhost:3000`) |
| `ansible.cfg` | Ansible configuration (points to inventory, disables host key checking for dynamic cloud IPs, enables YAML output callback) |
| `inventory.ini.example` | Template inventory file containing the target host and credentials |
| `inventory.ini` | Active inventory with the public IP from `make tf-output` |
| `playbooks/ping.yml` | Smoke test playbook to verify SSH connectivity |
| `playbooks/setup-docker.yml` | Idempotent playbook: installs Docker CE, Compose plugin, user groups, and verifies container engine |
| `SEMAPHORE.md` | Dedicated step-by-step guide for using Ansible Semaphore Web UI |
| `../docs/12-ansible.md` | Full chapter guide, concepts, pitfalls, and quiz |

---

## 1. Quick Start

### Step 1: Provision the VM (from Chapter 11)
If not already created, spin up `server2` in Azure:
```bash
make tf-apply
make tf-output
```
Note the VM's public IP address.

### Step 2: Configure the Inventory
Update `ansible/inventory.ini` with your VM's public IP:
```ini
[webservers]
server2 ansible_host=<YOUR_VM_PUBLIC_IP> ansible_user=azureuser ansible_ssh_private_key_file=/keys/server_key.pem
```

### Step 3: Test Connectivity
Verify that Ansible can connect to `server2` over SSH:
```bash
make ansible-ping
```
Expected output:
```json
server2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Step 4: Run the Setup Playbook
Provision Docker and Docker Compose on `server2`:
```bash
# Optional: dry-run first
make ansible-check

# Run full configuration
make ansible-setup
```

---

## 2. Using the Ansible Semaphore Web UI

Ansible Semaphore provides a modern web interface to view inventory, execute playbooks, and stream live task output.

For complete, step-by-step instructions on setting up a Project, Key Store, Inventory, Repository, and Task Templates, see the **[Semaphore UI Guide](SEMAPHORE.md)**.

1. **Start the Semaphore UI:**
   ```bash
   make up-ansible-ui
   ```
2. **Access the dashboard:**
   - URL: `http://localhost:3000`
   - Username: `admin`
   - Password: `admin`
3. **Stop the UI:**
   ```bash
   make down-ansible-ui
   ```
