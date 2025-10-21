# Deploy.sh – Automated Dockerized Application Deployment

## Overview

`deploy.sh` is a production-ready Bash script designed to automate the setup, deployment, and configuration of a Dockerized application on a remote Linux server using SSH, Docker, and Nginx.

This tool simplifies end-to-end deployment workflows by ensuring repeatability, idempotency, and clear logging.

---

## Features

* **Automated setup:** Installs Docker, Docker Compose, and NGINX.
* **Secure SSH deployment:** Transfers files safely via `rsync` or `scp`.
* **Smart repo handling:** Clones or updates Git repositories automatically.
* **Flexible builds:** Supports both Dockerfile and docker-compose.yml.
* **NGINX reverse proxy:** Dynamically configures proxy routing to your app.
* **Idempotent:** Safe to re-run without breaking existing setups.
* **Logging and error handling:** Full activity log and exit codes for each stage.

---

## Prerequisites

* A Linux-based remote server (Ubuntu 22.04 recommended)
* SSH access with a private key
* Docker installed (script installs it if missing)
* GitHub Personal Access Token (for private repos)
* Bash 5.0+

---

## Usage

### 1. Make the script executable

```bash
chmod +x deploy.sh
```

### 2. Run the script interactively

```bash
./deploy.sh
```

Follow the prompts to enter:

* Git repo URL
* Personal Access Token (PAT)
* Branch name (optional; defaults to main)
* Remote server username and IP
* SSH private key path
* Application port

### 3. Validate Deployment

Once complete, the script will output a success message and the endpoint where your app is accessible.

You can manually check:

```bash
curl http://<remote_server_ip>
```

---

## Cleanup

To remove the deployed application and resources, run:

```bash
./deploy.sh --cleanup
```

This will:

* Stop and remove Docker containers
* Remove project directory and NGINX config from the remote server
* Reload NGINX

---

## Log Files

All operations are logged to a timestamped file:

```
deploy_YYYYMMDD_HHMMSS.log
```

Located in the directory from which you execute the script.

---

## Notes

* Re-running the script will automatically update the existing deployment.
* The script uses default NGINX configuration for HTTP (port 80). You can add SSL manually or extend with Certbot.

---

## Example Output

```
=== Dockerized App Deployment Script ===
[INFO] Cloning repository...
[INFO] Found docker-compose.yml.
[INFO] Installing Docker and NGINX on remote server...
[INFO] Deploying containers...
[INFO] Deployment completed successfully! Access your app at http://<remote_server_ip>
```

---

## License

MIT License – Free to use and modify for your deployments.
