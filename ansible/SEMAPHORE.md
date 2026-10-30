# Ansible Semaphore UI Guide

**Ansible Semaphore** is an open-source, modern web dashboard for Ansible. It serves as a lightweight alternative to Red Hat Ansible Tower (AWX), providing a user-friendly UI for managing inventory, executing playbooks, scheduling tasks, and viewing live logs.

Like everything else in this course, Ansible Semaphore runs **100% inside Docker** with no host dependencies.

---

## 1. Quick Access

| Item | Value |
|---|---|
| **URL** | [http://localhost:3000](http://localhost:3000) or [http://127.0.0.1:3000](http://127.0.0.1:3000) |
| **Username** | `admin` |
| **Password** | `admin` |
| **Start Command** | `make up-ansible-ui` |
| **Stop Command** | `make down-ansible-ui` |
| **Reset / Wipe DB** | `make reset-ansible` |

---

## 2. Why a Web UI in Addition to CLI?

| Feature | Ansible CLI (`make ansible-*`) | Ansible Semaphore UI (`localhost:3000`) |
|---|---|---|
| **Primary Use** | Local development, CI/CD pipelines, quick tasks | Operations teams, non-technical users, audits |
| **Execution** | Terminal command | One-click button in web browser |
| **State & Logs** | Ephemeral (terminal buffer) | Centralized history, searchable logs, job tracking |
| **Source of Truth** | Local files on disk | Git repository (pulls latest code per run) |
| **Access Control** | Anyone with SSH keys & terminal access | Role-Based Access Control (RBAC) & user accounts |

---

## 3. Core Concepts in Semaphore

Semaphore organizes work into **Projects**. Before running a playbook, you configure four components inside your project:

```
┌────────────────────────────────────────────────────────┐
│                        PROJECT                         │
│                                                        │
│   1. Key Store      ➜  SSH Key (server_key.pem)        │
│   2. Inventory      ➜  Server IP (server2)             │
│   3. Repository     ➜  Git repository URL & branch     │
│   4. Task Template  ➜  Links Key + Inventory + Playbook│
└────────────────────────────────────────────────────────┘
```

---

## 4. Step-by-Step UI Configuration

### Step 1: Start and Log In
1. Start the service:
   ```bash
   make up-ansible-ui
   ```
2. Navigate to [http://localhost:3000](http://localhost:3000).
3. Log in with `admin` / `admin`.

---

### Step 2: Create a Project
1. Click **New Project** (or the **+** button next to Projects in the sidebar).
2. Enter a project name, e.g. `DevOps Course`.
3. Click **Save**.

---

### Step 3: Configure Key Store (SSH Key)
1. In the left sidebar, click **Key Store** $\rightarrow$ **New Key**.
2. Fill in:
   - **Name**: `server-key`
   - **Type**: `SSH Key`
   - **Username**: `azureuser`
   - **Private Key**: Paste the complete contents of `server_key.pem` (including the `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` headers).
3. Click **Save**.

---

### Step 4: Configure Inventory
1. In the left sidebar, click **Inventory** $\rightarrow$ **New Inventory**.
2. Fill in:
   - **Name**: `Azure Webservers`
   - **User Key**: Select `server-key`
   - **Type**: `Static`
   - **Inventory Content**: Paste the contents of your `ansible/inventory.ini` (replace `<YOUR_IP>` with the public IP from `make tf-output`):
     ```ini
     [webservers]
     server2 ansible_host=<YOUR_IP> ansible_user=azureuser
     ```
3. Click **Save**.

---

### Step 5: Configure Repository
1. In the left sidebar, click **Repositories** $\rightarrow$ **New Repository**.
2. Fill in:
   - **Name**: `DevOps Course Repo`
   - **Git URL**: Your repository URL:
     ```
     https://github.com/amanupadhyay/devops-course.git
     ```
   - **Git Branch**: `12-ansible`
   - **Access Key**: `None` (for public repositories) or an SSH/token key if private.
3. Click **Save**.

---

### Step 6: Create and Run a Task Template

> [!IMPORTANT]
> **Playbook Path Rule**: Semaphore clones the **entire root of the Git repository**.
> Therefore, the playbook path must be relative to the root of the repo:
> - **Correct**: `ansible/playbooks/setup-docker.yml`
> - **Incorrect**: `playbooks/setup-docker.yml` (will fail with `playbook could not be found`)

1. In the left sidebar, click **Task Templates** $\rightarrow$ **New Template**.
2. Fill in:
   - **Name**: `Provision Docker (server2)`
   - **Playbook filename**: `ansible/playbooks/setup-docker.yml`
   - **Inventory**: Select `Azure Webservers`
   - **Repository**: Select `DevOps Course Repo`
   - **Environment**: None (optional)
   - **View**: Default
3. Click **Save**.
4. Click **Run** on the template. A modal will pop up; click **Run** again to confirm.
5. Click on the running task to watch live, color-coded execution logs in real time!

---

## 5. Troubleshooting & FAQ

### Issue: `[ERROR]: the playbook: playbooks/setup-docker.yml could not be found`
- **Cause**: Semaphore executes `ansible-playbook` from the root directory of the cloned repository. In this repo, all Ansible files live under the `ansible/` subfolder.
- **Fix**: In your Task Template settings, set the playbook path to `ansible/playbooks/setup-docker.yml`.

### Issue: `No package matching 'docker-ce' is available` during Check Mode
- **Cause**: `--check` mode simulates tasks without actually modifying the server. Because the task that adds Docker's APT repository is only simulated, Ubuntu's package manager never receives the new package list and cannot find `docker-ce`.
- **Fix**: Run the task without `--check` (normal run). Once Docker is installed, subsequent check runs will succeed cleanly.

### Issue: Login failed with `admin` / `admin`
- **Cause**: The container was launched with an empty or uninitialized database.
- **Fix**: Run:
  ```bash
  make up-ansible-ui
  ```
  The make target automatically verifies that `admin` exists in the SQLite database and creates/resets it if missing.

### Issue: Resetting the entire UI state
- If you want to start fresh with a clean database:
  ```bash
  make reset-ansible
  make up-ansible-ui
  ```

