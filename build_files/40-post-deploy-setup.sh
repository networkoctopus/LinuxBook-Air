#!/bin/bash
set -ouex pipefail

### ── Per-user second-login setup ──
# Installs Toshy and restores the standard GNOME Flatpaks. The launcher skips
# the installer's initial session, then prompts on later logins until the setup
# completes or the user permanently skips it.

install -Dm755 /ctx/post-deploy-setup/post-deploy-setup.sh \
    /usr/libexec/linuxbook-air-post-deploy-setup.sh

install -Dm755 /ctx/post-deploy-setup/post-deploy-setup-launch.sh \
    /usr/libexec/linuxbook-air-post-deploy-setup-launch.sh

install -Dm644 /ctx/post-deploy-setup/post-deploy-setup.service \
    /usr/lib/systemd/user/linuxbook-air-post-deploy-setup.service

# Enable for all users via systemd user preset / wants symlink
mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/linuxbook-air-post-deploy-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/linuxbook-air-post-deploy-setup.service
