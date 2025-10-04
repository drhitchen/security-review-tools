# Python Environment Setup Guide

This guide provides instructions for setting up a proper Python environment for the security-review-tools repository.

## Setting Up pyenv

[pyenv](https://github.com/pyenv/pyenv) is a powerful tool for managing multiple Python versions on the same machine.

### Install pyenv via Homebrew

```sh
brew install pyenv
```

### Add pyenv to your shell

For zsh (default on newer macOS):

```sh
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
source ~/.zshrc
```

For bash:

```sh
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc
```

## Installing Python Versions

### View available Python versions

```sh
pyenv install --list | grep " 3\."
```

### Install specific Python versions

```sh
# Install latest 3.12 and 3.13
pyenv install 3.12:latest 3.13:latest
```

## Managing Python Versions

### Set a global Python version

```sh
# Set global Python version
pyenv global 3.12

# Verify global version
pyenv global
```

Expected output:
```
3.12
```
