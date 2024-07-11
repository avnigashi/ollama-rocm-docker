#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Prompt user for confirmation
prompt_install() {
  while true; do
    read -p "Do you want to install $1? [y/n]: " yn
    case $yn in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

# Install Docker if not installed
if ! command_exists docker; then
  if prompt_install "Docker"; then
    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker
  else
    echo "Skipping Docker installation."
  fi
else
  echo "Docker is already installed"
fi

# Install Docker Compose if not installed
if ! command_exists docker-compose; then
  if prompt_install "Docker Compose"; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  else
    echo "Skipping Docker Compose installation."
  fi
else
  echo "Docker Compose is already installed"
fi

# Install ROCm if not installed
if ! command_exists rocminfo; then
  if prompt_install "ROCm"; then
    echo "Installing ROCm..."
    sudo apt update
    sudo apt install -y wget
    wget -qO - http://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
    echo 'deb [arch=amd64] http://repo.radeon.com/rocm/apt/4.5/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt update
    sudo apt install -y rocm-dkms
    echo 'export PATH=/opt/rocm/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
    source ~/.bashrc
  else
    echo "Skipping ROCm installation."
  fi
else
  echo "ROCm is already installed"
fi

# Set up drun alias
if ! grep -q "alias drun=" ~/.bashrc; then
  echo "Setting up drun alias..."
  echo 'alias drun="sudo docker run -it -e HSA_OVERRIDE_GFX_VERSION=10.3.0 --network=host --device=/dev/kfd --device=/dev/dri --ipc=host --shm-size 16G --group-add video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v $(pwd):/current"' >> ~/.bashrc
  source ~/.bashrc
else
  echo "drun alias is already set up"
fi

# Create the ollama.sh script
OLLAMA_SCRIPT="/usr/local/bin/ollama.sh"
echo "Creating ollama.sh script..."
sudo bash -c "cat > $OLLAMA_SCRIPT" <<EOL
#!/bin/bash
sudo docker run -it -e HSA_OVERRIDE_GFX_VERSION=10.3.0 --network=host --device=/dev/kfd --device=/dev/dri --ipc=host --shm-size 16G --group-add video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v \$(pwd):/current ollama/ollama:rocm "\$@"
EOL
sudo chmod +x $OLLAMA_SCRIPT

# Create an alias for the ollama command
if ! grep -q "alias ollama=" ~/.bashrc; then
  echo "Creating alias for ollama command..."
  echo 'alias ollama="/usr/local/bin/ollama.sh"' >> ~/.bashrc
  source ~/.bashrc
else
  echo "ollama alias is already set up"
fi

# Output success message
echo "Setup complete. You can now use the 'ollama' command to run Ollama within the Docker container."
