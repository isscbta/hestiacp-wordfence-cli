#!/bin/bash
# Clear screen and print welcome message
clear
echo
echo "  _   _           _   _        ____ ____  "
echo " | | | | ___  ___| |_(_) __ _ / ___|  _ \ "
echo " | |_| |/ _ \/ __| __| |/ _\` | |   | |_) |"
echo " |  _  |  __/\__ \ |_| | (_| | |___|  __/ "
echo " |_| |_|\___||___/\__|_|\__,_|\____|_|    "
echo "                                          "
echo
echo '              HestiaCP Control Panel      '
echo -e "\n\n"

echo 'Following software will be installed on your system:'
echo '   - WordFence CLI'

CURDIR=$(pwd)

# Function to install Docker
install_docker() {
    echo "= Checking for Docker..."
    if ! command -v docker &> /dev/null; then
        echo "= Docker not found. Starting Docker installation."
        apt-get update > /dev/null 2>&1

        release=$(cat /etc/debian_version | tr "." "\n" | head -n1)
        if [ "$release" -gt 10 ]; then
            # Debian > 10
            apt-get install -y ca-certificates curl > /dev/null 2>&1
            echo "= Installing docker repo"
            install -m 0755 -d /etc/apt/keyrings && \
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
            chmod a+r /etc/apt/keyrings/docker.asc && \
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            echo "= Installing docker"
            apt-get update > /dev/null 2>&1
            apt-get install -y docker-ce docker-ce-cli containerd.io
            apt-get install -y docker-buildx-plugin docker-compose-plugin
        else
            # Debian < 11
            apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common lsb-release
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
            echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
            apt-get update > /dev/null 2>&1
            apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        if ! command -v docker &> /dev/null; then
            echo "- Error installing docker !!!";
            exit 1;
        fi
        # echo "= Creating docker group"
        # newgrp docker
        echo "= Installing docker-compose"
        curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url | grep docker-compose-linux-x86_64 | cut -d '"' -f 4 | wget -qi - && \
        chmod +x docker-compose-linux-x86_64 && \
        mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
        # docker-compose version
        systemctl restart docker
        echo "= Docker installation completed."
    else
        echo "= Docker is already installed."
    fi
}

# Install and configure WordFence CLI
install_wordfence_cli() {
    echo "= Starting WordFence CLI installation..."

    # Create HestiaCP Wordfence CLI directory
    mkdir -p /usr/local/hestia/wordfence-cli

    # Pull the custom Wordfence CLI image with Vectorscan installed
    echo "= Pulling WordFence CLI Docker image from Docker Hub..."
    docker pull isscbta/wordfence-cli:with-vectorscan-amd64 || {
        echo "- Failed to pull custom Wordfence CLI image."
        exit 1
    }

    # Tag the pulled image locally as 'wordfence-cli:latest'
    docker tag isscbta/wordfence-cli:with-vectorscan-amd64 wordfence-cli:latest

    echo "= WordFence CLI installation completed."

    # Only configure if configuration directory doesn't exist
    if [ ! -d "/usr/local/hestia/wfcli-conf" ]; then
        echo "= Starting WordFence CLI configuration..."

        # Run 'configure' in an interactive container
        docker run -it -v /var/www:/var/www wordfence-cli:latest configure

        # Find the container that ran the 'configure' command
        CONFCONTAINER=$(docker ps -a | grep 'wordfence configure' | head -n 1 | awk '{print $NF}')

        docker start "$CONFCONTAINER"
        CONFCONTENT=$(docker exec -it "$CONFCONTAINER" cat ~/.config/wordfence/wordfence-cli.ini)
        docker stop "$CONFCONTAINER"

        mkdir -p /usr/local/hestia/wfcli-conf
        echo "$CONFCONTENT" > /usr/local/hestia/wfcli-conf/wordfence-cli.ini

        if [ -s /usr/local/hestia/wfcli-conf/wordfence-cli.ini ]; then
            echo "= WordFence CLI configuration completed successfully."
            cat /usr/local/hestia/wfcli-conf/wordfence-cli.ini
        else
            echo "- WordFence CLI configuration failed. The configuration file is empty or missing."
        fi
    fi
}

# Final setup steps
final_setup() {
    wget -q -O /usr/local/hestia/bin/v-get-database-credentials https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-get-database-credentials-of-domain
    wget -q -O /usr/local/hestia/bin/v-wf-malware-scan https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-wf-malware-scan
    wget -q -O /usr/local/hestia/bin/v-wf-malware-hyperscan https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-wf-malware-hyperscan
    wget -q -O /usr/local/hestia/bin/v-wf-vulnerability-scan https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-wf-vulnerability-scan
    wget -q -O /usr/local/hestia/bin/v-wf-remediate https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-wf-remediate
    wget -q -O /usr/local/hestia/bin/v-wf-db-scan https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-wf-db-scan
    wget -q -O /usr/local/hestia/bin/v-wf-scan-path https://raw.githubusercontent.com/isscbta/hestiacp-wordfence-cli/refs/heads/main/bin/v-wf-scan-path
    chmod a+x /usr/local/hestia/bin/v-get-database-credentials
    chmod a+x /usr/local/hestia/bin/v-wf-malware-scan
    chmod a+x /usr/local/hestia/bin/v-wf-vulnerability-scan
    chmod a+x /usr/local/hestia/bin/v-wf-remediate
    chmod a+x /usr/local/hestia/bin/v-wf-db-scan
    chmod a+x /usr/local/hestia/bin/v-wf-malware-hyperscan
    chmod a+x /usr/local/hestia/bin/v-wf-scan-path
    echo "==============================="
    echo "WordFence CLI is ready to use."
    echo "==============================="
    echo ""
    echo "Use:"
    echo "v-wf-malware-scan DOMAIN"
    echo "... for malware scanning."
    echo ""
    echo "Use:"
    echo "v-wf-malware-hyperscan DOMAIN"
    echo "... for hyper malware scanning."
    echo ""
    echo "Use:"
    echo "v-wf-scan-path /some/path"
    echo "... for path scanning."
    echo ""
    echo "Use:"
    echo "v-wf-vulnerability-scan DOMAIN"
    echo "... for vulnerability scanning."
    echo ""
    echo "Use:"
    echo "v-wf-remediate DOMAIN"
    echo "... for automatically repairing known files belonging to a WordPress installation"
    echo ""
    echo "Use:"
    echo "v-wf-db-scan DOMAIN"
    echo "... for scanning WordPress database"
    echo ""
    echo "Append --progress, --banner, etc., at the end of the command to include additional parameters. A full list of parameters can be found on the WordFence CLI documentation page."
    echo ""
    echo "==============================="
}

# Main installation process
install_docker
install_wordfence_cli
final_setup
