

# 🪶 Project 2 — Full-Stack Serverless Guestbook (AWS + Terraform)

A **fully serverless, full-stack web application** built on **AWS** and managed via **Terraform**.
This project implements a **public Guestbook** where users can submit and view messages in real time — all deployed automatically using **GitHub Actions**.

Every part of the system — from static site hosting to backend APIs — is **defined as code**, enabling repeatable, version-controlled deployments.

---

## 🖼️ Live Demo Screenshot

![Guestbook Application Interface](https://github.com/Keninjavelas/AWS-Serverless-Contact-Form/blob/main/Guestbook.png?raw=true)

*The Guestbook web interface displaying real-time user submissions.*


---

## 🚀 Core Features

* 🧩 **Full-Stack CRUD** – Create and read guestbook messages instantly
* ⚡ **Dynamic Frontend** – Updates live, no page reloads
* 🔁 **Instant Refresh** – New messages appear at the top immediately
* ✉️ **Email Alerts** – Admin notifications via Amazon SES
* 🔄 **Automated CI/CD** – Managed entirely via GitHub Actions and OIDC
* ☁️ **100% Serverless** – Powered by AWS managed services

---

## 🏗️ Architecture Overview

### **Frontend**

* Hosted in a **private Amazon S3 bucket**
* Delivered through **CloudFront CDN** with HTTPS
* Secured using **Origin Access Control (OAC)** to restrict access to CloudFront only

### **Backend**

* **API Gateway (HTTP API)** exposing:

  * `/submit` → Create message endpoint
  * `/messages` → Fetch message list
* **AWS Lambda (Python)** handlers:

  * `submit_handler.py` → Writes messages to DynamoDB + triggers SES email
  * `read_handler.py` → Reads messages from DynamoDB
* **DynamoDB** – Stores all guestbook entries
* **Amazon SES** – Sends notification emails to the admin

---

## 🧭 Data Flow

### 📝 Write Flow (`POST /submit`)

1. User submits a form on the frontend
2. Browser sends POST request to API Gateway
3. API Gateway invokes the **Submit Lambda**
4. Lambda:

   * Writes data to **DynamoDB**
   * Sends email via **SES**
   * Returns `200 OK`

### 🔍 Read Flow (`GET /messages`)

1. Frontend calls `/messages` endpoint
2. API Gateway triggers the **Read Lambda**
3. Lambda:

   * Scans **DynamoDB**
   * Sorts entries (newest first)
   * Returns JSON response
4. Frontend dynamically updates the live message feed

---

## ☁️ AWS Services Used

| Service             | Purpose                                   |
| ------------------- | ----------------------------------------- |
| **S3**              | Hosts frontend assets (HTML, CSS, JS)     |
| **CloudFront**      | HTTPS delivery + caching                  |
| **API Gateway**     | RESTful API endpoints                     |
| **Lambda (Python)** | Serverless backend logic                  |
| **DynamoDB**        | NoSQL data store                          |
| **SES**             | Sends email notifications                 |
| **IAM**             | OIDC access + least-privilege permissions |
| **CloudWatch**      | Logs and monitoring                       |

---

## ⚙️ CI/CD Automation — GitHub Actions

### 🧩 Backend Deployment

**Workflow:** `.github/workflows/backend-deploy.yml`
**Trigger:** Push to `backend/`
**Auth:** Secure OIDC → AWS IAM Role (no stored keys)

**Steps:**

```bash
terraform init
terraform validate
terraform apply -auto-approve
```

> Deploys AWS infrastructure automatically via Terraform.

---

### 🖥️ Frontend Deployment

**Workflow:** `.github/workflows/frontend-deploy.yml`
**Trigger:** Push to `frontend/`
**Auth:** Uses the same OIDC IAM Role

**Steps:**

```bash
aws s3 sync ./frontend s3://<your-bucket-name> --delete
aws cloudfront create-invalidation --distribution-id <distribution-id> --paths "/*"
```

> Syncs static frontend files and refreshes CloudFront cache globally.

---

## 🔒 Security Highlights

* 🔐 **OIDC Authentication:** GitHub securely assumes AWS Role (no static keys)
* 🚫 **Private S3 Access:** Only CloudFront can fetch files (via OAC)
* 🌍 **CORS Restriction:** API Gateway only accepts requests from your CloudFront domain
* 🧱 **Least Privilege IAM:** Lambdas have only required permissions
* 📊 **CloudWatch Logs:** Complete visibility into API + Lambda events

---

## 📂 Repository Structure

```
serverless-guestbook/
├── backend/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── dynamodb.tf
│   └── lambda/
│       ├── submit_handler.py
│       └── read_handler.py
│
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── app.js
│
├── .github/
│   └── workflows/
│       ├── backend-deploy.yml
│       └── frontend-deploy.yml
│
├── Guestbook.png
└── README.md
```

---

## 🧪 Local Development

1. **Install Terraform**

   ```bash
   brew install terraform
   ```
2. **Initialize & Validate**

   ```bash
   cd backend
   terraform init
   terraform validate
   ```
3. **Deploy Infrastructure**

   ```bash
   terraform apply -auto-approve
   ```
4. **Update Frontend**
   Commit or push to `/frontend/` — GitHub Actions redeploys automatically.

---

## 🧱 Lambda Environment Variables

| Variable         | Description                       |
| ---------------- | --------------------------------- |
| `TABLE_NAME`     | DynamoDB table name               |
| `EMAIL_SENDER`   | Verified SES sender address       |
| `EMAIL_RECEIVER` | Admin recipient for notifications |

---

## 📜 License

Licensed under the **MIT License** — free for personal, educational, and commercial use.

---

## 🌟 Credits

Built with ❤️ using:

* **AWS Serverless Stack** (Lambda, API Gateway, DynamoDB, SES)
* **Terraform** for Infrastructure-as-Code
* **GitHub Actions** for CI/CD via OIDC

---

