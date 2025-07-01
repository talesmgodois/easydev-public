#!/bin/bash

set -euo pipefail

CHECKPOINT_FILE="$HOME/.devsetup_checkpoint"

declare -A STEP_FUNCS
declare -a STEP_ORDER=(
  "essentials"
  "zsh"
  "nvm"
  "docker"
)

# Define all installation steps as functions
essentials() {
  echo "Installing essentials..."
  sudo apt update
  sudo apt install -y git curl wget vim neovim
}

zsh() {
  echo "Installing zsh and Oh My Zsh..."
  sudo apt install -y zsh
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  chsh -s "$(which zsh)"
}

nvm() {
  echo "Installing NVM and Node..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  source "$HOME/.nvm/nvm.sh"
  nvm install --lts
}

docker() {
  echo "🐳 Installing Docker..."
  sudo apt remove -y docker docker-engine docker.io containerd runc || true
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker $USER

}

docker() {
  echo "🐳 Installing Docker..."

  # Use Ubuntu codename for Mint
  BASE_CODENAME=$(lsb_release -cs)
  [[ "$BASE_CODENAME" == "xia" ]] && BASE_CODENAME="noble"

  echo "🔑 Adding Docker repository key and source for Ubuntu $BASE_CODENAME..."

  # Install prerequisite packages
  sudo apt update
  sudo apt install -y ca-certificates curl

  # Add Docker's official GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the Docker repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $BASE_CODENAME stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  echo "📦 Updating package index and installing Docker..."
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "👥 Adding current user to docker group..."
  sudo usermod -aG docker $USER

  echo "✅ Docker installed successfully."
  echo "⚠️  Note: You may need to log out and back in for group changes to take effect."
  echo "You can test your installation with: docker run hello-world"
}


# Define other functions similarly...

# Link function names to labels
for label in "${STEP_ORDER[@]}"; do
  STEP_FUNCS[$label]=$label
done

# Get the starting step
start_from="${1:-}"
if [[ -n "$start_from" ]]; then
  echo "$start_from" >"$CHECKPOINT_FILE"
fi

should_run=false

for step in "${STEP_ORDER[@]}"; do
  if [[ ! -f "$CHECKPOINT_FILE" || "$should_run" = true ]]; then
    echo "🔹 Running step: $step"
    ${STEP_FUNCS[$step]}
    echo "$step" >"$CHECKPOINT_FILE"
  elif [[ "$(cat $CHECKPOINT_FILE)" == "$step" ]]; then
    should_run=true
    echo "🔹 Resuming from: $step"
    ${STEP_FUNCS[$step]}
    echo "$step" >"$CHECKPOINT_FILE"
  else
    echo "⏭️  Skipping $step..."
  fi
done

echo "✅ All steps completed."
rm -f "$CHECKPOINT_FILE"
