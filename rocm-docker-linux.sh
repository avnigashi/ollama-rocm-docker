#!/bin/bash

# Function to check the last command status and exit if it failed
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 installation failed."
        exit 1
    else
        echo "$1 installed successfully."
    fi
}

# Function to prompt for reinstallation
prompt_reinstall() {
    read -p "$1 is already installed. Do you want to reinstall it? (y/n): " REINSTALL
    if [[ $REINSTALL =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if the system has been rebooted
read -p "Have you rebooted the system after the initial setup? (y/n): " REBOOTED
if [[ $REBOOTED =~ ^[Nn]$ ]]; then
    echo "Please reboot the system and then rerun this script."
    exit 0
fi

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y
check_status "System update"

# Install wget if not already installed
if dpkg -l | grep -q wget; then
    prompt_reinstall "wget"
    if [ $? -eq 0 ]; then
        echo "Reinstalling wget..."
        sudo apt install -y --reinstall wget
        check_status "wget"
    else
        echo "Skipping wget installation."
    fi
else
    echo "Installing wget..."
    sudo apt install -y wget
    check_status "wget"
fi

# Install Docker if not already installed
if dpkg -l | grep -q docker.io; then
    prompt_reinstall "Docker"
    if [ $? -eq 0 ]; then
        echo "Reinstalling Docker..."
        sudo apt install -y --reinstall docker.io
        check_status "Docker"
    else
        echo "Skipping Docker installation."
    fi
else
    echo "Installing Docker..."
    sudo apt install -y docker.io
    check_status "Docker"
fi

# Install Docker Compose if not already installed
if ! docker compose version &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    check_status "Docker Compose installation"
else
    prompt_reinstall "Docker Compose"
    if [ $? -eq 0 ]; then
        echo "Reinstalling Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        check_status "Docker Compose reinstallation"
    else
        echo "Skipping Docker Compose installation."
    fi
fi

# Start and enable Docker service
echo "Starting and enabling Docker service..."
sudo systemctl start docker
sudo systemctl enable docker
check_status "Docker service"

# Add user to Docker group
echo "Adding user to Docker group..."
sudo usermod -aG docker $USER
check_status "Docker group modification"

# Download and install the latest AMDGPU repository package
if dpkg -l | grep -q amdgpu-install; then
    prompt_reinstall "AMDGPU repository"
    if [ $? -eq 0 ]; then
        echo "Downloading AMDGPU repository package..."
        wget https://repo.radeon.com/amdgpu-install/6.1.2/ubuntu/jammy/amdgpu-install_6.1.60102-1_all.deb
        check_status "Download AMDGPU repository"

        echo "Reinstalling AMDGPU repository package..."
        sudo apt install -y ./amdgpu-install_6.1.60102-1_all.deb
        check_status "AMDGPU repository installation"
    else
        echo "Skipping AMDGPU repository installation."
    fi
else
    echo "Downloading AMDGPU repository package..."
    wget https://repo.radeon.com/amdgpu-install/6.1.2/ubuntu/jammy/amdgpu-install_6.1.60102-1_all.deb
    check_status "Download AMDGPU repository"

    echo "Installing AMDGPU repository package..."
    sudo apt install -y ./amdgpu-install_6.1.60102-1_all.deb
    check_status "AMDGPU repository installation"
fi

# Install ROCm using amdgpu-install script without the conflicting options
if dpkg -l | grep -q rocm-dkms; then
    prompt_reinstall "ROCm"
    if [ $? -eq 0 ]; then
        echo "Reinstalling ROCm using amdgpu-install script..."
        sudo amdgpu-install --usecase=rocm,hip
        check_status "ROCm installation"
    else
        echo "Skipping ROCm installation."
    fi
else
    echo "Installing ROCm using amdgpu-install script..."
    sudo amdgpu-install --usecase=rocm,hip
    check_status "ROCm installation"
fi

# Pull ROCm Docker image if not already pulled
if sudo docker images | grep -q rocm/rocm-terminal; then
    prompt_reinstall "ROCm Docker image"
    if [ $? -eq 0 ]; then
        echo "Pulling ROCm Docker image..."
        sudo docker pull rocm/rocm-terminal
        check_status "ROCm Docker image pull"
    else
        echo "Skipping ROCm Docker image pull."
    fi
else
    echo "Pulling ROCm Docker image..."
    sudo docker pull rocm/rocm-terminal
    check_status "ROCm Docker image pull"
fi

# Install PyTorch with ROCm support if not already installed
if pip3 show torch &> /dev/null; then
    prompt_reinstall "PyTorch"
    if [ $? -eq 0 ]; then
        echo "Installing PyTorch with ROCm support..."
        pip3 install --upgrade torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm5.4.2
        check_status "PyTorch"
    else
        echo "Skipping PyTorch installation."
    fi
else
    echo "Installing PyTorch with ROCm support..."
    pip3 install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm5.4.2
    check_status "PyTorch"
fi

# Install TensorFlow with ROCm support if not already installed
if pip3 show tensorflow-rocm &> /dev/null; then
    prompt_reinstall "TensorFlow"
    if [ $? -eq 0 ]; then
        echo "Installing TensorFlow with ROCm support..."
        pip3 install --upgrade tensorflow-rocm
        check_status "TensorFlow"
    else
        echo "Skipping TensorFlow installation."
    fi
else
    echo "Installing TensorFlow with ROCm support..."
    pip3 install tensorflow-rocm
    check_status "TensorFlow"
fi

# Setting up Docker run alias
echo "Setting up Docker run alias..."
ALIAS="alias drun='sudo docker run -it -e HSA_OVERRIDE_GFX_VERSION=10.3.0 --network=host --device=/dev/kfd --device=/dev/dri --ipc=host --shm-size 16G --group-add video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v $(pwd):/current'"
echo $ALIAS >> ~/.bashrc
source ~/.bashrc
check_status "Docker run alias setup"

# Check if ROCm was installed but not working
if ! rocminfo &> /dev/null; then
    echo "ROCm appears to be installed but is not working. A reboot may be required."
    read -p "Would you like to reboot now? (y/n): " REBOOT_NOW
    if [[ $REBOOT_NOW =~ ^[Yy]$ ]]; then
        echo "Rebooting system..."
        sudo reboot
    else
        echo "Please reboot the system later to ensure ROCm is functioning properly."
    fi
fi

echo "Installation complete. Please log out and log back in for the changes to take effect."
