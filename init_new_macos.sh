#!/bin/bash

set -euo pipefail

CHECKPOINT_FILE="$HOME/.mac_devsetup_checkpoint"

declare -A STEP_FUNCS
declare -a STEP_ORDER=(
  "xcode"
  "homebrew"
  "essentials"
  "zsh"
  "nvm"
  "vscode"
  "tmux"
  "docker"
  "gitlab_cli"
)

# Define all installation steps as functions
xcode() {
  echo "Installing Xcode Command Line Tools..."
  if ! xcode-select -p &>/dev/null; then
    xcode-select --install
    # Wait until Xcode tools are installed
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  else
    echo "Xcode Command Line Tools already installed."
  fi
}

homebrew() {
  echo "Installing Homebrew..."
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH
    if [[ "$(uname -m)" == "arm64" ]]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    echo "Homebrew already installed."
  fi
}

essentials() {
  echo "Installing essentials..."
  brew install git curl wget vim neovim
}

zsh() {
  echo "Installing zsh and Oh My Zsh..."
  if [[ "$SHELL" != */zsh ]]; then
    brew install zsh
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    sudo dscl . -change /Users/$USER UserShell $SHELL $(which zsh) > /dev/null
  else
    echo "zsh is already the default shell."
  fi
}

nvm() {
  echo "Installing NVM and Node..."
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
  else
    echo "NVM already installed."
  fi
}

vscode() {
  echo "Installing VS Code..."
  if ! brew list --cask visual-studio-code &>/dev/null; then
    brew install --cask visual-studio-code
    # Install VS Code command line tools
    if ! command -v code &>/dev/null; then
      cat << EOF >> ~/.zprofile
# Add Visual Studio Code (code)
export PATH="\$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
EOF
      export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    fi
  else
    echo "VS Code already installed."
  fi
}

tmux() {
  echo "Installing tmux..."
  brew install tmux
}

docker() {
  echo "🐳 Installing Docker for Mac..."
  if ! brew list --cask docker &>/dev/null; then
    brew install --cask docker
    echo "Docker installed. You'll need to open Docker.app from the Applications folder to complete setup."
  else
    echo "Docker already installed."
  fi
}

gitlab_cli() {
  echo "Installing GitLab CLI (glab)..."
  if ! command -v glab &>/dev/null; then
    brew install glab
  else
    echo "GitLab CLI already installed."
  fi

  echo -n "Do you want to configure glab for a self-hosted GitLab instance? (y/n) "
  read -r configure_self_hosted
  if [[ "$configure_self_hosted" =~ ^[Yy]$ ]]; then
    echo -n "Enter your GitLab self-hosted URL (e.g., https://gitlab.example.com): "
    read -r gitlab_url
    echo -n "Enter your GitLab API token (create one at ${gitlab_url}/-/profile/personal_access_tokens): "
    read -r gitlab_token
    
    glab auth login --hostname "$(echo "$gitlab_url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')" --token "$gitlab_token"
    
    echo "GitLab CLI configured for: $gitlab_url"
    echo "You can now use commands like:"
    echo "  glab issue create"
    echo "  glab mr list"
    echo "  glab repo clone <project>"
  else
    echo "You can configure glab later by running: glab auth login"
  fi
}

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