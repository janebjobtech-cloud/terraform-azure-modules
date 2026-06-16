# ☁️ Cloud Blueprint — Automating a Secure VPC, Bastion & Multi-Server AWS Infrastructure with Terraform

> **A production-grade, fully automated AWS infrastructure deployment using Terraform IaC — built from scratch, documented step by step.**

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture Diagram](#-architecture-diagram)
- [Infrastructure Components](#-infrastructure-components)
- [Prerequisites](#-prerequisites)
- [Project Structure](#-project-structure)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration)
- [Deployment](#-deployment)
- [Validation & Testing](#-validation--testing)
- [Connecting to Your Infrastructure](#-connecting-to-your-infrastructure)
- [VPC Flow Logs](#-vpc-flow-logs)
- [Security Design](#-security-design)
- [Troubleshooting](#-troubleshooting)
- [Lessons Learned](#-lessons-learned)
- [Clean Up](#-clean-up)
- [Author](#-author)

---

## 🎯 Project Overview

This project automates the deployment of a **secure, multi-tier AWS cloud infrastructure** using **Terraform** as the Infrastructure as Code (IaC) tool. Instead of manually clicking through the AWS Console, every resource is defined as code — meaning the entire environment can be built, torn down, and rebuilt identically with a single command.

### What This Project Builds

| Component | Description |
|-----------|-------------|
| **VPC** | A private, isolated network with a custom CIDR block |
| **4 Subnets** | 2 Public (internet-facing) + 2 Private (hidden) across 2 Availability Zones |
| **Internet Gateway** | The single public entry point into the VPC |
| **NAT Gateway** | Allows private servers to reach the internet (for updates/installs) without being exposed |
| **Bastion Host** | A hardened jump server in the public subnet — the only SSH entry point |
| **Linux Web Server** | Apache web server running in the private subnet, accessible only via SSH tunnel |
| **Windows Web Server** | IIS web server running in the private subnet, accessible only via RDP tunnel |
| **Security Groups** | Per-server firewalls locked to a specific corporate IP |
| **VPC Flow Logs** | Full network traffic recording sent to CloudWatch Logs |

### Project Requirements Delivered

- ✅ **Req 1** — Dev team can SSH to the Bastion and tunnel into the Linux web server
- ✅ **Req 2** — Dev team can RDP into the Windows web server via secure tunnel
- ✅ **Req 3** — All access is restricted to the corporate network IP only (`/32`)
- ✅ **Req 4** — All scenarios tested and validated end-to-end

---

## 🏗️ Architecture Diagram

```
                          ┌─────────────────────────────────────────────────────────────────┐
                          │                     AWS Cloud — us-east-1                        │
                          │                                                                   │
    🌍 The Internet  ────►│  🚪 Internet Gateway (myproject-igw)                            │
   (Corporate IP only)    │       │                                                          │
   173.79.145.53/32       │       ▼                                                          │
                          │  ┌──────────────────────────────────────────────────────────┐    │
                          │  │              VPC — myproject-vpc (10.0.0.0/16)           │    │
                          │  │                                                          │    │
                          │  │  ┌─────────────────────┐  ┌─────────────────────────┐   │    │
                          │  │  │  PUBLIC SUBNET 1     │  │  PUBLIC SUBNET 2        │   │    │
                          │  │  │  10.0.1.0/24         │  │  10.0.2.0/24            │   │    │
                          │  │  │  us-east-1a          │  │  us-east-1b             │   │    │
                          │  │  │                      │  │                         │   │    │
                          │  │  │  🖥️ BASTION HOST     │  │  🔀 NAT Gateway         │   │    │
                          │  │  │  t3.micro            │  │  (Outbound only)        │   │    │
                          │  │  │  Amazon Linux 2023   │  │                         │   │    │
                          │  │  │  Public IP: Assigned │  │                         │   │    │
                          │  │  │  SG: Port 22 only    │  │                         │   │    │
                          │  │  │  from corp IP        │  │                         │   │    │
                          │  │  └──────────┬──────────┘  └─────────────────────────┘   │    │
                          │  │             │ SSH Tunnel / Jump                          │    │
                          │  │             ▼                                            │    │
                          │  │  ┌─────────────────────┐  ┌─────────────────────────┐   │    │
                          │  │  │  PRIVATE SUBNET 1    │  │  PRIVATE SUBNET 2       │   │    │
                          │  │  │  10.0.11.0/24        │  │  10.0.12.0/24           │   │    │
                          │  │  │  us-east-1a          │  │  us-east-1b             │   │    │
                          │  │  │                      │  │                         │   │    │
                          │  │  │  🐧 LINUX WEB SERVER │  │  🪟 WINDOWS WEB SERVER  │   │    │
                          │  │  │  t3.micro            │  │  t3.micro               │   │    │
                          │  │  │  Amazon Linux 2023   │  │  Windows Server 2022    │   │    │
                          │  │  │  Apache (httpd)      │  │  IIS Web Server         │   │    │
                          │  │  │  NO Public IP        │  │  NO Public IP           │   │    │
                          │  │  │  SG: SSH from        │  │  SG: RDP (3389) from    │   │    │
                          │  │  │  Bastion SG only     │  │  Bastion SG + corp IP   │   │    │
                          │  │  └─────────────────────┘  └─────────────────────────┘   │    │
                          │  │                                                          │    │
                          │  │  📋 VPC Flow Logs ──────────────────► CloudWatch Logs   │    │
                          │  └──────────────────────────────────────────────────────────┘    │
                          │                                                                   │
                          │  🪣 S3 / IAM (AWS Managed — accessed via AWS backbone)           │
                          └─────────────────────────────────────────────────────────────────┘


  CONNECTION FLOWS:
  ─────────────────
  [1] SSH to Bastion:     Your Laptop ──SSH:22──► Bastion (Public IP) ✅ corp IP only
  [2] Tunnel to Linux:    Your Laptop ──SSH Tunnel──► Bastion ──SSH:22──► Linux Server
  [3] RDP to Windows:     Your Laptop ──RDP Tunnel──► Bastion ──RDP:3389──► Windows Server
  [4] Outbound (servers): Private Servers ──► NAT Gateway ──► Internet (downloads only)
```

---

## 🧩 Infrastructure Components

### Network Layer

| Resource | Name | CIDR / Details |
|----------|------|----------------|
| VPC | `myproject-vpc` | `10.0.0.0/16` |
| Public Subnet 1 | `myproject-public-subnet-1` | `10.0.1.0/24` — us-east-1a |
| Public Subnet 2 | `myproject-public-subnet-2` | `10.0.2.0/24` — us-east-1b |
| Private Subnet 1 | `myproject-private-subnet-1` | `10.0.11.0/24` — us-east-1a |
| Private Subnet 2 | `myproject-private-subnet-2` | `10.0.12.0/24` — us-east-1b |
| Internet Gateway | `myproject-igw` | Attached to VPC |
| NAT Gateway | `myproject-nat-gw` | In Public Subnet 1 |
| Public Route Table | `myproject-public-rt` | `0.0.0.0/0` → IGW |
| Private Route Table | `myproject-private-rt` | `0.0.0.0/0` → NAT GW |

### Compute Layer

| Server | Role | Subnet | Instance Type | OS | Public IP |
|--------|------|--------|---------------|----|-----------|
| `myproject-bastion` | Jump Server | Public Subnet 1 | t3.micro | Amazon Linux 2023 | ✅ Yes |
| `myproject-linux-web` | Web Server | Private Subnet 1 | t3.micro | Amazon Linux 2023 | ❌ No |
| `myproject-windows-web` | Web Server | Private Subnet 2 | t3.micro | Windows Server 2022 | ❌ No |

### Security Layer

| Security Group | Attached To | Inbound Rules |
|----------------|-------------|---------------|
| `myproject-bastion-sg` | Bastion | Port 22 from `YOUR_IP/32` only |
| `myproject-linux-web-sg` | Linux Server | Port 22 from Bastion SG · Port 80/443 from VPC |
| `myproject-windows-web-sg` | Windows Server | Port 3389 from Bastion SG + `YOUR_IP/32` · Port 80/443 from VPC |

---

## ✅ Prerequisites

Before you begin, make sure you have the following:

### Tools Required

```bash
# Terraform >= 1.5.0
terraform version

# AWS CLI v2
aws --version

# SSH client (built into Windows 10/11, Mac, Linux)
ssh -V
```

### Install Links

| Tool | Download |
|------|----------|
| Terraform | https://developer.hashicorp.com/terraform/install |
| AWS CLI v2 | https://awscli.amazonaws.com/AWSCLIV2.msi (Windows) |
| Git | https://git-scm.com/downloads |

### AWS Account Requirements

- An active AWS account
- IAM user with programmatic access (Access Key ID + Secret Access Key)
- Permissions: EC2, VPC, CloudWatch, IAM (for flow logs role)

---

## 📁 Project Structure

```
infra/
├── main.tf               # VPC, subnets, IGW, NAT GW, route tables, flow logs, key pair
├── variables.tf          # Input variable definitions
├── locals.tf             # Shared resource tags
├── security_groups.tf    # Bastion, Linux, and Windows security groups
├── compute.tf            # EC2 instances — Bastion, Linux web, Windows web
├── outputs.tf            # Post-deploy outputs: IPs, IDs, ready-to-use SSH commands
└── terraform.tfvars      # YOUR personal values (never commit this to git)
```

### What Each File Does

**`main.tf`** — The master builder. Creates the entire network foundation: VPC, 4 subnets, Internet Gateway, NAT Gateway, Route Tables, VPC Flow Logs, CloudWatch Log Group, IAM role, and SSH Key Pair.

**`variables.tf`** — The settings form. Defines what information Terraform needs before building anything — region, project name, CIDRs, your corporate IP, your SSH public key, and instance sizes.

**`locals.tf`** — The labeling file. Stamps every single AWS resource with consistent tags so you can always identify what belongs to this project.

**`security_groups.tf`** — The firewall file. Three separate Security Groups, each with precise rules. The most security-critical file in the project.

**`compute.tf`** — The servers file. Launches all three EC2 instances with automated bootstrap scripts that install and configure Apache (Linux) and IIS (Windows) on first boot.

**`outputs.tf`** — The results file. After `terraform apply`, prints all IPs, IDs, and ready-to-run SSH tunnel and jump commands so you can connect immediately.

**`terraform.tfvars`** — Your personal values file. Contains your actual IP and SSH key. **Never commit this file to a public repository.**

---

## ⚡ Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/YOUR_USERNAME/aws-vpc-project.git
cd aws-vpc-project/infra

# 2. Get your public IP (your "corporate network")
curl https://api.ipify.org

# 3. Get your SSH public key (generate one if needed)
cat ~/.ssh/id_rsa.pub
# If no key exists: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# 4. Copy and fill in your personal values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your IP and SSH key

# 5. Configure AWS credentials
aws configure

# 6. Initialize, plan, and deploy
terraform init
terraform plan
terraform apply
```

---

## ⚙️ Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values:

```hcl
# terraform.tfvars

aws_region = "us-east-1"
project    = "myproject"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Your home/corporate public IP — run: curl https://api.ipify.org
corporate_cidr = "YOUR_PUBLIC_IP/32"

# Your SSH public key — run: cat ~/.ssh/id_rsa.pub
ssh_public_key = "ssh-rsa AAAA..."

# Instance types
bastion_instance_type = "t3.micro"
linux_instance_type   = "t3.micro"
windows_instance_type = "t3.micro"

environment = "dev"
```

> ⚠️ **Security Notice:** Never commit `terraform.tfvars` to a public repository. It contains your IP address and SSH public key. The `.gitignore` file in this project already excludes it.

---

## 🚀 Deployment

### Step 1 — Initialize Terraform

Downloads the AWS provider plugin. Run once per project.

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 2 — Preview the Plan

Shows exactly what will be created before touching anything in AWS.

```bash
terraform plan
```

Expected output:
```
Plan: 26 to add, 0 to change, 0 to destroy.
```

### Step 3 — Apply (Deploy Everything)

Builds your entire infrastructure. Takes 3–5 minutes.

```bash
terraform apply
```

Type `yes` when prompted. After completion, Terraform prints all outputs:

```
Outputs:

bastion_public_ip       = "18.205.6.234"
linux_web_private_ip    = "10.0.11.227"
windows_web_private_ip  = "10.0.12.140"
ssh_tunnel_command      = "ssh -i ~/.ssh/id_rsa -L 8080:10.0.11.227:80 ec2-user@18.205.6.234 -N"
ssh_jump_command        = "ssh -i ~/.ssh/id_rsa -J ec2-user@18.205.6.234 ec2-user@10.0.11.227"
flow_logs_log_group     = "/aws/vpc/flow-logs/myproject"
vpc_id                  = "vpc-0c9448e797537c611"
```

> 💡 Save these outputs — you will need the IPs and commands in the next steps.

---

## 🧪 Validation & Testing

### Scenario 1 — SSH to the Bastion

```bash
ssh -i ~/.ssh/id_rsa ec2-user@BASTION_PUBLIC_IP
```

Expected result: You land on the Bastion's command line.
```
[ec2-user@ip-10-0-1-xxx ~]$
```

### Scenario 2 — SSH Tunnel to Linux Web Server

**Open the tunnel** (leave this running in a dedicated terminal window):

```bash
ssh -i ~/.ssh/id_rsa -L 8080:LINUX_PRIVATE_IP:80 ec2-user@BASTION_PUBLIC_IP -N
```

**Test in your browser:**
```
http://localhost:8080
```

Expected result: A webpage displaying **"Linux Web Server is UP"** with the private IP `10.0.11.227`.

**Alternative — SSH jump directly to Linux server:**

```bash
ssh -i ~/.ssh/id_rsa -J ec2-user@BASTION_PUBLIC_IP ec2-user@LINUX_PRIVATE_IP
```

### Scenario 3 — RDP to Windows Web Server

**Open the RDP tunnel** (leave this running in a dedicated terminal window):

```bash
# Mac/Linux
ssh -i ~/.ssh/id_rsa -L 3389:WINDOWS_PRIVATE_IP:3389 ec2-user@BASTION_PUBLIC_IP -N

# Windows PowerShell
ssh -i C:\Users\YOUR_USER\.ssh\id_rsa -L 3389:WINDOWS_PRIVATE_IP:3389 ec2-user@BASTION_PUBLIC_IP -N
```

**Get the Windows password from AWS Console:**
1. EC2 → Instances → select `myproject-windows-web`
2. Actions → Security → Get Windows password
3. Upload your private key file → Decrypt password

**Connect via Remote Desktop:**
- Computer: `localhost:3389`
- Username: `.\Administrator`
- Password: retrieved from AWS Console above

Expected result: Windows Server 2022 desktop appears.

### Run All Tests Automatically

```bash
bash validate_all.sh
```

Expected output:
```
============================================================
  Results: 5 passed · 0 failed
============================================================
  🎉 All tests passed! Your infrastructure is working correctly.
```

---

## 🔌 Connecting to Your Infrastructure

### SSH Key Path Reference

| OS | Key Path |
|----|----------|
| Windows | `C:\Users\YOUR_USERNAME\.ssh\id_rsa` |
| Mac / Linux | `~/.ssh/id_rsa` |

### Ready-to-Use Commands (from terraform output)

```bash
# View all outputs at any time
terraform output

# SSH tunnel to Linux web server (port forward)
terraform output -raw ssh_tunnel_command

# SSH jump to Linux web server (direct shell)
terraform output -raw ssh_jump_command
```

### Windows PowerShell Note

On Windows, use `C:\Users\YOUR_USER\.ssh\id_rsa` instead of `~/.ssh/id_rsa` in all SSH commands:

```powershell
# SSH to Bastion
ssh -i C:\Users\buroj\.ssh\id_rsa ec2-user@BASTION_IP

# SSH tunnel to Linux
ssh -i C:\Users\buroj\.ssh\id_rsa -L 8080:LINUX_IP:80 ec2-user@BASTION_IP -N

# RDP tunnel to Windows
ssh -i C:\Users\buroj\.ssh\id_rsa -L 3389:WINDOWS_IP:3389 ec2-user@BASTION_IP -N
```

---

## 📊 VPC Flow Logs

All network traffic in this VPC is automatically recorded to CloudWatch Logs.

### View Your Flow Logs

1. AWS Console → CloudWatch → Log groups
2. Click `/aws/vpc/flow-logs/myproject`
3. Click any log stream to see entries

### Reading Flow Log Entries

```
# Format: version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action
2 123456789012 eni-xxx 173.79.145.53 10.0.1.10 54321 22 6 5 320 1716600000 1716600060 ACCEPT OK
                        ^YOUR IP      ^BASTION   ^SRC  ^22=SSH                              ^ALLOWED IN

2 123456789012 eni-xxx 198.51.100.99 10.0.1.10 33421 22 6 1 40 1716600100 1716600160 REJECT OK
                        ^UNKNOWN IP   ^BASTION                                          ^BLOCKED
```

| Entry Type | Meaning |
|------------|---------|
| `ACCEPT OK` | Connection was allowed through |
| `REJECT OK` | Connection was blocked by Security Group |
| `NODATA` | Interface was active but no traffic in this window |

Flow logs are retained for **30 days** and then automatically deleted.

---

## 🔐 Security Design

This project follows the **principle of least privilege** — every server gets only the exact access it needs and nothing more.

### Corporate Network Restriction

All inbound access is locked to a single IP address (`corporate_cidr = "YOUR_IP/32"`). This means:
- The Bastion SSH port (`22`) only responds to your IP
- The Windows RDP port (`3389`) only responds to your IP
- Every other IP on the internet gets **silently dropped** — no response, no error

### Bastion Pattern

The Bastion acts as the **single controlled entry point** into the private network:

```
Internet → Bastion (public) → Linux Server (private)
Internet → Bastion (public) → Windows Server (private)
```

No private server is ever directly exposed. If the Bastion is compromised, private servers remain protected behind their own Security Groups.

### Security Group Chaining

The Linux server's Security Group references the **Bastion Security Group** as its SSH source — not an IP address. This means only traffic that already authenticated through the Bastion can reach the Linux server:

```hcl
ingress {
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [aws_security_group.bastion.id]  # ← SG reference, not IP
}
```

### Encrypted Storage

All EC2 root volumes use **gp3 encrypted storage** (`encrypted = true`) to protect data at rest.

### SSH Hardening

Both Linux servers have password authentication disabled on boot:
```bash
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
```

---

## 🔧 Troubleshooting

### terraform plan fails — No valid credential sources

```bash
# Configure AWS credentials
aws configure

# Verify connection
aws sts get-caller-identity
```

### SSH connection refused to Bastion

1. Check your current IP hasn't changed: `curl https://api.ipify.org`
2. If your IP changed, update `corporate_cidr` in `terraform.tfvars` and run `terraform apply`
3. Verify the Bastion instance is in **Running** state in EC2 console

### Browser shows "This site can't be reached" on localhost:8080

1. Confirm the SSH tunnel window is still open and running
2. Check Apache is running on the Linux server:
   ```bash
   ssh -i ~/.ssh/id_rsa -J ec2-user@BASTION_IP ec2-user@LINUX_IP
   sudo systemctl status httpd
   ```
3. If Apache is not running: `sudo systemctl start httpd`

### RDP connection fails to Windows server

1. Windows Server takes **10–15 minutes** to fully boot after launch — wait and retry
2. Verify the RDP tunnel is open in a separate terminal
3. Test the tunnel: `Test-NetConnection -ComputerName localhost -Port 3389`
4. Ensure you are using username `.\Administrator` (with the dot-backslash prefix)

### Private servers can't download packages (yum/apt times out)

The NAT Gateway may not be provisioned yet or the private route table may be missing the NAT route. Verify:

```bash
terraform apply  # Re-run to ensure NAT Gateway and route are applied
```

### SSH key format rejected by AWS Console

Convert from OpenSSH format to RSA PEM format:

```bash
ssh-keygen -p -m PEM -f ~/.ssh/id_rsa -N ""
```

---

## 💡 Lessons Learned

Building this project from scratch surfaced some important real-world insights:

**PowerShell vs Linux terminal** — Commands are not interchangeable. The `&&` operator does not work in PowerShell. Always confirm your environment before running commands.

**Credentials security** — AWS Access Keys are the master key to your entire account. The moment they are exposed anywhere, deactivate and regenerate them immediately.

**Always run terraform plan first** — It previews every action before anything is created. It catches problems — wrong instance types, unsupported characters in descriptions, missing permissions — before they cost money or cause outages.

**Special characters cause unexpected failures** — AWS Security Group descriptions reject non-ASCII characters. Auto-generated Windows passwords with `&`, `%`, and `$` can be impossible to paste correctly. Keep passwords and descriptions simple.

**Private subnets block both directions** — A server in a private subnet cannot reach the internet to download software. A NAT Gateway is required to allow outbound-only internet access from private subnets.

**Security Groups are the most powerful AWS security tool** — They can reference each other, creating chained trust. They silently drop unauthorized traffic — no error, no acknowledgment, just silence.

**SSH key formats matter** — OpenSSH format and RSA PEM format are not interchangeable across all tools. Know your key format and how to convert it when needed.

**Windows servers boot slowly** — Plan for 10–15 minutes before RDP is available. Attempting to connect too early generates misleading errors.

**Terraform makes recovery fast** — When something is broken, `terraform taint` + `terraform apply` destroys and rebuilds a single resource in minutes without touching the rest of the infrastructure.

**VPC Flow Logs are non-negotiable** — Without them, you are blind to everything happening on your network. Always enable them from day one.

---

## 🧹 Clean Up

To avoid ongoing AWS charges, destroy all resources when you are done:

```bash
terraform destroy
```

Type `yes` when prompted. This will permanently delete:
- All EC2 instances (Bastion, Linux, Windows)
- VPC, subnets, Internet Gateway, NAT Gateway
- Security Groups, Route Tables
- VPC Flow Log, CloudWatch Log Group, IAM Role
- SSH Key Pair

> ⚠️ **This action is irreversible.** All data on the instances will be lost.

---

## 📸 Project Screenshots

| Step | Screenshot |
|------|------------|
| Terraform init success | `screenshot-01b-terraform-init-success.png` |
| Terraform plan — 23 resources | `screenshot-01e-terraform-plan-success.png` |
| Terraform apply complete | `screenshot-02-terraform-apply-complete.png` |
| All 3 instances running in EC2 | `screenshot-05-all-instances-running.png` |
| Linux Web Server via SSH tunnel | `screenshot-04-linux-web-server-via-tunnel.png` |
| TcpTestSucceeded — RDP tunnel open | `screenshot-06-rdp-tunnel-test-success.png` |
| Windows Server 2022 desktop via RDP | `screenshot-09-windows-rdp-success.png` |
| VPC Flow Logs capturing traffic | `screenshot-10b-flow-logs-entries.png` |

---

## 🗂️ What Was Built — Final Summary

| Resource | Value |
|----------|-------|
| VPC ID | `vpc-0c9448e797537c611` |
| Public Subnet 1 | `subnet-026e4819ab79b5363` (us-east-1a) |
| Public Subnet 2 | `subnet-0a7565591158d1516` (us-east-1b) |
| Private Subnet 1 | `subnet-0d72771b4f6a3357c` (us-east-1a) |
| Private Subnet 2 | `subnet-03154c9e8d0f54111` (us-east-1b) |
| Bastion Public IP | `18.205.6.234` |
| Linux Server Private IP | `10.0.11.227` |
| Windows Server Private IP | `10.0.12.140` |
| Flow Logs Log Group | `/aws/vpc/flow-logs/myproject` |
| Total Resources Deployed | **26** |

---

## 👤 Author

**Jane Buro**
Cloud & Infrastructure Engineer

This lab was completed as a hands-on project to demonstrate real-world AWS infrastructure design, Terraform IaC automation, network security architecture, and end-to-end connectivity validation across Linux and Windows environments.

---

## 📄 License

This project is for educational and portfolio purposes.

---

## 🙏 Acknowledgements

- [HashiCorp Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [AWS VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/index.html)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)

---

*Built with ☁️ on AWS · Automated with 🏗️ Terraform · Secured with 🔐 IAM + Security Groups*
