#!/usr/bin/env bash

set -oue pipefail

# Install adw-gtk3
VER=$(basename $(curl --retry 3 -Ls -o /dev/null -w %{url_effective} https://github.com/lassekongo83/adw-gtk3/releases/latest)) && curl --retry 3 -fLs --create-dirs https://github.com/lassekongo83/adw-gtk3/releases/download/${VER}/adw-gtk3${VER}.tar.xz -o /tmp/adw-gtk3.tar.gz

mkdir -p /etc/skel/.local/share/themes/
tar -xf /tmp/adw-gtk3.tar.gz -C /etc/skel/.local/share/themes/
rm /tmp/adw-gtk3.tar.gz

echo "${VER#v}" > /etc/skel/.local/share/themes/.adw-gtk3-version

# Install WhiteSur Icon Theme
mkdir -p /tmp/WhiteSur-icons
git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icons
/tmp/WhiteSur-icons/install.sh -a -b -d '/usr/share/icons'
rm -rf /tmp/WhiteSur-icons

# Monaspace Fonts
DOWNLOAD_URL=$(curl --retry 3 https://api.github.com/repos/githubnext/monaspace/releases/latest | jq -r '.assets[] | select(.name| test(".*.zip$")).browser_download_url')
curl --retry 3 -Lo /tmp/monaspace-font.zip "$DOWNLOAD_URL"

unzip -qo /tmp/monaspace-font.zip -d /tmp/monaspace-font
mkdir -p /usr/share/fonts/monaspace
mv /tmp/monaspace-font/monaspace-v*/fonts/otf/* /usr/share/fonts/monaspace/
rm -rf /tmp/monaspace-font*

fc-cache -fv

# Remove avif thumbnailer, as HEIF thumbnailer already covers it
rm /usr/share/thumbnailers/avif.thumbnailer

# Install DevPod
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64" && install -c -m 0755 devpod /usr/local/bin && rm -f devpod

# Extra guards against using package managers
PACKAGE_MANAGERS=(
	"/usr/bin/dnf"
	"/usr/bin/dnf5"
	"/usr/bin/yum"
)

for MGR in "${PACKAGE_MANAGERS[@]}"; do
	cat <<EOF >"${MGR}"
    #!/usr/bin/env bash

    echo "Package/application layering is disabled."
EOF
done

# Enable experimental Bluetooth features to make it more compatible with Bluetooth Battery Meter extension
sed -i 's/#Experimental = false/Experimental = true/; s/#Experimental = true/Experimental = true/; s/Experimental = false/Experimental = true/; s/#KernelExperimental = false/KernelExperimental = true/; s/#KernelExperimental = true/KernelExperimental = true/; s/KernelExperimental = false/KernelExperimental = true/; s/#Experimental=false/Experimental = true/; s/#Experimental=true/Experimental = true/; s/Experimental=false/Experimental = true/; s/#KernelExperimental=false/KernelExperimental = true/; s/#KernelExperimental=true/KernelExperimental = true/; s/KernelExperimental=false/KernelExperimental = true/' /etc/bluetooth/main.conf