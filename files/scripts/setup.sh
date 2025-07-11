#!/usr/bin/env bash

set -oue pipefail

# Install WhiteSur Icon Theme
mkdir -p /tmp/WhiteSur-icons
git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icons
/tmp/WhiteSur-icons/install.sh -a -b -d '/usr/share/icons'
rm -rf /tmp/WhiteSur-icons

# Fonts: Monaspace, Microsoft Fonts, SF Pro
FONTS_DIR="/usr/share/fonts"

DOWNLOAD_URL=$(curl --retry 3 https://api.github.com/repos/githubnext/monaspace/releases/latest | jq -r '.assets[] | select(.name| test(".*.zip$")).browser_download_url')
curl --retry 3 -Lo /tmp/monaspace-font.zip "$DOWNLOAD_URL"

unzip -qo /tmp/monaspace-font.zip -d /tmp/monaspace-font
mkdir -p /usr/share/fonts/monaspace
mv /tmp/monaspace-font/monaspace-v*/fonts/otf/* /usr/share/fonts/monaspace/
rm -rf /tmp/monaspace-font*

curl --retry 3 -Lo ${FONTS_DIR}/fonts.tar.xz "https://linux.hemsley.dev/019733d3-970c-7168-978d-523401ccbe3a-fonts.tar.xz"
tar -xvJf ${FONTS_DIR}/fonts.tar.xz -C ${FONTS_DIR}/
rm ${FONTS_DIR}/fonts.tar.xz

fc-cache -fv

# Remove avif thumbnailer, as HEIF thumbnailer already covers it

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