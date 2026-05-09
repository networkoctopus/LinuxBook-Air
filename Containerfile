# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/silverblue-main:44
## Other possible base images include:
# FROM quay.io/fedora/fedora-silverblue:latest  (tracks latest stable)
# FROM ghcr.io/ublue-os/bluefin:stable
# FROM ghcr.io/ublue-os/bazzite:stable
#
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base images: quay.io/fedora/fedora-silverblue

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.
# RUN rm /opt && mkdir /opt

### KMODS
## wl (broadcom): installed via ublue akmods pre-built image (avoids akmod-wl root build failure)
COPY --from=ghcr.io/ublue-os/akmods:main-44 / /tmp/akmods-common
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf install -y \
    /tmp/akmods-common/rpms/ublue-os/ublue-os-akmods-addons*.rpm \
    /tmp/akmods-common/rpms/common/broadcom-wl*.rpm \
    /tmp/akmods-common/rpms/kmods/kmod-wl*.rpm && \
    rm -rf /tmp/akmods-common /run/akmods /run/dnf
## facetimehd
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y copr enable mulderje/facetimehd-kmod && \
    dnf5 install -y --setopt=tsflags=noscripts facetimehd-kmod facetimehd facetimehd-firmware && \
    dnf5 -y copr disable mulderje/facetimehd-kmod && \
    echo "=== Builder kernel: $(uname -r) ===" && \
    echo "=== Target kernel: $(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-devel) ===" && \
    akmods --force --kernels $(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-devel) && \
    dnf5 -y mark user facetimehd facetimehd-firmware && \
    dnf5 remove -y akmod-facetimehd akmods kmodtool kernel-devel kernel-devel-matched kernel-headers && \
    dnf5 autoremove -y && \
    rm -rf /var/cache/akmods /run/akmods /run/dnf

### Toshy first login setup
COPY --from=ctx /usr/libexec/toshy-first-login-setup.sh   /usr/libexec/toshy-first-login-setup.sh
COPY --from=ctx /usr/libexec/toshy-first-login-launch.sh  /usr/libexec/toshy-first-login-launch.sh
COPY --from=ctx /usr/lib/systemd/user/toshy-first-login-setup.service \
                /usr/lib/systemd/user/toshy-first-login-setup.service

RUN chmod +x /usr/libexec/toshy-first-login-setup.sh \
             /usr/libexec/toshy-first-login-launch.sh \
 && mkdir -p /usr/lib/systemd/user/graphical-session.target.wants \
 && ln -sf /usr/lib/systemd/user/toshy-first-login-setup.service \
           /usr/lib/systemd/user/graphical-session.target.wants/toshy-first-login-setup.service

### Add gnome extenstions to the image
RUN /usr/bin/bash <<'EOF'
set -euo pipefail

GNOME_VERSION=$(rpm -q --queryformat '%{VERSION}' gnome-shell | cut -d. -f1)
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
mkdir -p "$EXTENSIONS_DIR"

install_extension() {
    local ext_id="$1"
    local uuid="$2"

    echo "Installing extension $uuid (ID: $ext_id) for GNOME ${GNOME_VERSION}..."

    local version_tag
    version_tag=$(curl -sf "https://extensions.gnome.org/extension-info/?pk=${ext_id}&shell_version=${GNOME_VERSION}" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["version_tag"])')

    local tmpdir
    tmpdir=$(mktemp -d)
    curl -sL "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_tag}" \
        -o "$tmpdir/ext.zip"
    unzip -q "$tmpdir/ext.zip" -d "${EXTENSIONS_DIR}/${uuid}"
    rm -rf "$tmpdir"

    echo "Done: $uuid"
}

install_extension 615  "appindicatorsupport@rgcjonas.gmail.com"
install_extension 5060 "xremap@k0kubun.com"
install_extension 1460 "Vitals@CoreCoding.com"
install_extension 19   "user-theme@gnome-shell-extensions.gcampax.github.com"
install_extension 307  "dash-to-dock@micxgx.gmail.com"

EOF

RUN cat > /usr/share/glib-2.0/schemas/99-custom-extensions.gschema.override << 'EOF'
[org.gnome.shell]
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'xremap@k0kubun.com', 'Vitals@CoreCoding.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com']
disable-user-extensions=false
EOF

RUN glib-compile-schemas /usr/share/glib-2.0/schemas

### Stop gnome software from trying to update packages and causing conflicts with bootc's deployment process. This is done by removing the dnf5 plugin for gnome software, and masking packagekit to prevent it from being started as a dependency of the plugin.
RUN rm -f /usr/lib64/gnome-software/plugins-*/libgs_plugin_dnf5.so && \
    systemctl mask packagekit && \
    echo "gnome-software dnf5 plugin removed"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
