#!/usr/bin/env bash

# ===============================================
# Automated Dockerized Application Deployment Script
# ===============================================
# Author: Your Name
# Date: $(date +%Y-%m-%d)
# Description: Automates setup, deployment, and configuration of a Dockerized app on a remote server.
# ===============================================

set -euo pipefail

LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
trap 'echo "[ERROR] An unexpected error occurred. Check log file: $LOG_FILE" | tee -a "$LOG_FILE"' ERR

echo "\n=== Dockerized App Deployment Script ===\n" | tee -a "$LOG_FILE"

# ---------- Step 1: Collect Parameters ----------
read -rp "Enter Git repository URL: " REPO_URL
read -rp "Enter Personal Access Token (PAT): " PAT
read -rp "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -rp "Enter remote server username: " SSH_USER
read -rp "Enter remote server IP address: " SSH_HOST
read -rp "Enter SSH private key path: " SSH_KEY
read -rp "Enter application port (container internal port): " APP_PORT

# Validate inputs
if [[ -z "$REPO_URL" || -z "$PAT" || -z "$SSH_USER" || -z "$SSH_HOST" || -z "$SSH_KEY" || -z "$APP_PORT" ]]; then
  echo "[ERROR] All fields are required." | tee -a "$LOG_FILE"
  exit 1
fi

# ---------- Step 2: Clone or Update Repository ----------
REPO_DIR=$(basename "$REPO_URL" .git)

if [[ -d "$REPO_DIR" ]]; then
  echo "[INFO] Repository exists. Pulling latest changes..." | tee -a "$LOG_FILE"
  cd "$REPO_DIR"
  git pull origin "$BRANCH" | tee -a "../$LOG_FILE"
else
  echo "[INFO] Cloning repository..." | tee -a "$LOG_FILE"
  git clone -b "$BRANCH" "https://${PAT}@${REPO_URL#https://}" | tee -a "$LOG_FILE"
  cd "$REPO_DIR"
fi

# ---------- Step 3: Validate Docker Configuration ----------
if [[ -f "docker-compose.yml" ]]; then
  DEPLOY_TYPE="compose"
  echo "[INFO] Found docker-compose.yml." | tee -a "../$LOG_FILE"
elif [[ -f "Dockerfile" ]]; then
  DEPLOY_TYPE="dockerfile"
  echo "[INFO] Found Dockerfile." | tee -a "../$LOG_FILE"
else
  echo "[ERROR] No Dockerfile or docker-compose.yml found." | tee -a "../$LOG_FILE"
  exit 1
fi

# ---------- Step 4: Test Remote Connection ----------
echo "[INFO] Testing SSH connection..." | tee -a "../$LOG_FILE"
ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$SSH_USER@$SSH_HOST" "echo SSH connection successful" | tee -a "../$LOG_FILE"

# ---------- Step 5: Prepare Remote Environment ----------
REMOTE_SETUP="sudo apt update -y && sudo apt install -y docker.io docker-compose nginx && \
               sudo systemctl enable docker nginx && sudo systemctl start docker nginx && \
               sudo usermod -aG docker $SSH_USER && docker --version && docker-compose --version && nginx -v"
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "$REMOTE_SETUP" | tee -a "../$LOG_FILE"

# ---------- Step 6: Transfer Files ----------
echo "[INFO] Transferring project files to remote server..." | tee -a "../$LOG_FILE"
rsync -avz -e "ssh -i $SSH_KEY" ./ "$SSH_USER@$SSH_HOST:/home/$SSH_USER/$REPO_DIR" | tee -a "../$LOG_FILE"

# ---------- Step 7: Deploy Application ----------
REMOTE_DEPLOY="cd /home/$SSH_USER/$REPO_DIR && \
if [ '$DEPLOY_TYPE' = 'compose' ]; then docker-compose down && docker-compose up -d --build; \
else docker build -t ${REPO_DIR}_image . && docker run -d -p $APP_PORT:$APP_PORT --name ${REPO_DIR}_container ${REPO_DIR}_image; fi"
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "$REMOTE_DEPLOY" | tee -a "../$LOG_FILE"

# ---------- Step 8: Configure NGINX Reverse Proxy ----------
NGINX_CONF="/etc/nginx/sites-available/$REPO_DIR"
NGINX_SETUP="echo 'server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}' | sudo tee $NGINX_CONF && sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/ && sudo nginx -t && sudo systemctl reload nginx"
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "$NGINX_SETUP" | tee -a "../$LOG_FILE"

# ---------- Step 9: Validate Deployment ----------
echo "[INFO] Validating remote deployment..." | tee -a "../$LOG_FILE"
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker ps | grep $REPO_DIR" | tee -a "../$LOG_FILE"
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "curl -I http://localhost" | tee -a "../$LOG_FILE"

echo "\n[INFO] Deployment completed successfully! Access your app at http://$SSH_HOST" | tee -a "../$LOG_FILE"

# ---------- Optional Cleanup ----------
if [[ ${1:-} == "--cleanup" ]]; then
  echo "[INFO] Cleaning up remote deployment..." | tee -a "$LOG_FILE"
  ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" "docker-compose down || docker stop ${REPO_DIR}_container && docker rm ${REPO_DIR}_container && sudo rm -rf /home/$SSH_USER/$REPO_DIR /etc/nginx/sites-available/$REPO_DIR /etc/nginx/sites-enabled/$REPO_DIR && sudo systemctl reload nginx" | tee -a "$LOG_FILE"
  echo "[INFO] Cleanup completed." | tee -a "$LOG_FILE"
fi
