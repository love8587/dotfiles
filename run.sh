#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}' | cut -d'-' -f1)"
OS_ARCH="$(uname -m)"

if [ "${OS_NAME}" == "darwin" ]; then
  INSTALLER="brew"
elif [ "${OS_NAME}" == "mingw64_nt" ]; then
  INSTALLER="choco"
fi

################################################################################

command -v tput > /dev/null && TPUT=true

_echo() {
  if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
    echo -e "$(tput setaf $2)$1$(tput sgr0)"
  else
    echo -e "$1"
  fi
}

_read() {
  if [ "${TPUT}" != "" ]; then
    printf "$(tput setaf 6)$1$(tput sgr0)"
  else
    printf "$1"
  fi
  read ANSWER
}

_result() {
  _echo "# $@" 4
}

_command() {
  _echo "$ $@" 3
}

_success() {
  _echo "+ $@" 2
  exit 0
}

_error() {
  _echo "- $@" 1
  exit 1
}

_git_config() {
  DEFAULT="$(whoami)"
  _read "Please input git user name [${DEFAULT}]: "

  GIT_USERNAME="${ANSWER:-${DEFAULT}}"
  git config --global user.name "${GIT_USERNAME}"

  DEFAULT="${GIT_USERNAME}@daangn.com"
  _read "Please input git user email [${DEFAULT}]: "

  GIT_USEREMAIL="${ANSWER:-${DEFAULT}}"
  git config --global user.email "${GIT_USEREMAIL}"

  _command "git config --list"
  git config --list
}

_install_brew() {
  INSTALLED=
  command -v $1 > /dev/null || INSTALLED=false
  if [ ! -z ${INSTALLED} ]; then
    _command "brew install ${2:-$1}"
    brew install ${2:-$1}
  fi
}

_install_brew_path() {
  INSTALLED=$(cat /tmp/brew_list | grep "$1" | wc -l | xargs)

  if [ "x${INSTALLED}" == "x0" ]; then
    _command "brew install ${2:-$1}"
    brew install ${2:-$1}
  fi
}

_install_brew_apps() {
  INSTALLED=$(ls /Applications/ | grep "$1" | wc -l | xargs)

  if [ "x${INSTALLED}" == "x0" ]; then
    _command "brew install -cask ${2:-$1}"
    brew install -cask ${2:-$1}
  fi
}

_install_npm() {
  INSTALLED=
  command -v $1 > /dev/null || INSTALLED=false
  if [ ! -z ${INSTALLED} ]; then
    _command "npm install -g ${2:-$1}"
    npm install -g ${2:-$1}
  fi
}

_install_npm_path() {
  if [ -d /usr/local/lib/node_modules/ ]; then
    INSTALLED=$(ls /usr/local/lib/node_modules/ | grep "$1" | wc -l | xargs)
  else
    INSTALLED=
  fi

  if [ "x${INSTALLED}" == "x0" ]; then
    _command "npm install -g ${2:-$1}"
    npm install -g ${2:-$1}
  fi
}

################################################################################

_result "${OS_NAME} ${OS_ARCH} [${INSTALLER}]"

if [ "${INSTALLER}" == "" ]; then
  _error "Not supported OS."
fi

mkdir -p ~/.aws
mkdir -p ~/.ssh

# ssh keygen
[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -q -f ~/.ssh/id_rsa -N ''
[ ! -f ~/.ssh/id_ed25519 ] && ssh-keygen -q -t ed25519 -f ~/.ssh/id_ed25519 -N ''

# ssh config
if [ ! -f ~/.ssh/config ]; then
  curl -fsSL -o ~/.ssh/config https://raw.githubusercontent.com/daangn/dotfiles/main/.ssh/config
  chmod 600 ~/.ssh/config
fi

# aws config
if [ ! -f ~/.aws/config ]; then
  curl -fsSL -o ~/.aws/config https://raw.githubusercontent.com/daangn/dotfiles/main/.aws/config
  chmod 600 ~/.aws/config
fi

# .aliases
if [ ! -f ~/.aliases ]; then
  curl -fsSL -o ~/.aliases https://raw.githubusercontent.com/daangn/dotfiles/main/.aliases
fi

# .vimrc
if [ ! -f ~/.vimrc ]; then
  curl -fsSL -o ~/.vimrc https://raw.githubusercontent.com/daangn/dotfiles/main/.vimrc
fi

# git config
GIT_USERNAME="$(git config --global user.name)"
if [ -z ${GIT_USERNAME} ]; then
  _git_config
fi

# brew for mac
if [ "${INSTALLER}" == "brew" ]; then
  command -v xcode-select > /dev/null || HAS_XCODE=false
  if [ ! -z ${HAS_XCODE} ]; then
    _command "xcode-select --install"
    sudo xcodebuild -license
    xcode-select --install

    if [ "${OS_ARCH}" == "arm64" ]; then
      sudo softwareupdate --install-rosetta --agree-to-license
    fi
  fi

  # ₩ -> `
  if [ ! -f ~/Library/KeyBindings/DefaultkeyBinding.dict ]; then
    mkdir -p ~/Library/KeyBindings/
    curl -fsSL -o ~/Library/KeyBindings/DefaultkeyBinding.dict https://raw.githubusercontent.com/daangn/dotfiles/main/.mac/DefaultkeyBinding.dict
  fi

  # brew
  command -v brew > /dev/null || HAS_BREW=false
  if [ ! -z ${HAS_BREW} ]; then
    _command "brew install..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -d "/opt/homebrew/bin" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(brew shellenv)"
    fi
  fi

  _command "brew update..."
  brew update

  _command "brew upgrade..."
  brew upgrade

  brew list > /tmp/brew_list

  # zsh
  command -v zsh > /dev/null || HAS_ZSH=false
  if [ ! -z ${HAS_ZSH} ]; then
    _command "brew install zsh"
    brew install zsh
    chsh -s /bin/zsh
  fi

  # oh-my-zsh
  if [ ! -d ~/.oh-my-zsh ]; then
    /bin/bash -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
  fi

  # getopt
  GETOPT=$(getopt 2>&1 | head -1 | xargs)
  if [ "${GETOPT}" == "--" ]; then
    _command "brew install gnu-getopt"
    brew install gnu-getopt
    brew link --force gnu-getopt
  fi

  # Brewfile
  if [ -f ~/.Brewfile ] && [ ! -f ~/.Brewfile.backup ]; then
    cp ~/.Brewfile ~/.Brewfile.backup
  fi
  curl -fsSL -o ~/.Brewfile https://raw.githubusercontent.com/daangn/dotfiles/main/Brewfile

  _command "brew bundle..."
  brew bundle --file=~/.Brewfile

  _command "check versions..."
  _result "awscli:  $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
  _result "kubectl: $(kubectl version --client -o json | jq .clientVersion.gitVersion -r)"
  _result "helm:    $(helm version --client --short | cut -d'+' -f1)"
  _result "argocd:  $(argocd version --client -o json | jq .client.Version -r | cut -d'+' -f1)"

  _command "brew cleanup..."
  brew cleanup
fi

# .bashrc
if [ ! -f ~/.bashrc ]; then
  curl -fsSL -o ~/.bashrc https://raw.githubusercontent.com/daangn/dotfiles/main/.bashrc
fi

# .zshrc
if [ ! -f ~/.zshrc ]; then
  curl -fsSL -o ~/.zshrc https://raw.githubusercontent.com/daangn/dotfiles/main/.zshrc
fi

# .zprofile
if [ ! -f ~/.zprofile ]; then
if [ -d /opt/homebrew/bin ]; then
  curl -fsSL -o ~/.zprofile https://raw.githubusercontent.com/daangn/dotfiles/main/.zprofile.arm
else
  curl -fsSL -o ~/.zprofile https://raw.githubusercontent.com/daangn/dotfiles/main/.zprofile
fi
fi

_success
