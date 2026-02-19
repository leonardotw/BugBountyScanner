#!/bin/bash
## Automated Bug Bounty recon script dependency installer
## By Cas van Cooten

if [ "$EUID" -ne 0 ]
then
  echo "[-] Installation requires elevated privileges, please run as root"
  echo "[*] Running 'sudo $0' will install for current user"
  echo "[*] Running 'sudo su; $0' will install for root user"
  exit 1
fi

if [[ "$OSTYPE" != "linux-gnu" ]]
then
  echo "[-] Installation requires Linux"
  exit 1
fi

# Detect system architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        echo "[*] Detected x86_64 architecture"
        ARCH_SUFFIX="amd64"
        ;;
    aarch64|arm64)
        echo "[*] Detected ARM64 architecture"
        ARCH_SUFFIX="arm64"
        ;;
    *)
        echo "[-] Unsupported architecture: $ARCH"
        echo "[-] This script supports x86_64 and ARM64 architectures only"
        exit 1
        ;;
esac

for arg in "$@"
do
    case $arg in
        -h|--help)
        echo "BugBountyHunter Dependency Installer"
        echo " "
        echo "$0 [options]"
        echo " "
        echo "options:"
        echo "-h, --help                show brief help"
        echo "-t, --toolsdir            tools directory, defaults to '/opt'"
        echo ""
        echo "Note: If you choose a non-default tools directory, please adapt the default in the BugBountyAutomator.sh file or pass the -t flag to ensure it finds the right tools."
        echo ""
        echo "example:"
        echo "$0 -t /opt"
        exit 0
        ;;
        -t|--toolsdir)
        toolsDir="$2"
        shift
        shift
        ;;
    esac
done

if [ -z "$toolsDir" ]
then
    toolsDir="/opt"
fi

echo "[*] INSTALLING DEPENDENCIES IN \"$toolsDir\"..."
echo "[!] NOTE: INSTALLATION HAS BEEN TESTED ON UBUNTU ONLY. RESULTS MAY VARY FOR OTHER DISTRIBUTIONS."
echo "[*] DETECTED ARCHITECTURE: $ARCH ($ARCH_SUFFIX)"

baseDir=$PWD
username="$(logname 2>/dev/null || echo root)"
# Safer home dir expansion
homeDir=$(getent passwd "$username" | cut -d: -f6)
# Fallback if getent fails or returns empty (e.g. inside some minimal containers)
if [ -z "$homeDir" ]; then
    homeDir="$HOME"
fi

mkdir -p "$toolsDir"
cd "$toolsDir" || { echo "Something went wrong"; exit 1; }

# Various apt packages
echo "[*] Running apt update and installing apt-based packages, this may take a while..."
apt-get update >/dev/null
apt-get install -y xvfb dnsutils nmap python3 python3-pip curl wget unzip git libfreetype6 libfontconfig1 >/dev/null
rm -rf /var/lib/apt/lists/*

# Chromium (for gowitness/katana) is installed via apt in Dockerfile or below
if ! command -v chromium &> /dev/null && ! command -v chromium-browser &> /dev/null; then
    echo "[*] Installing Chromium..."
    apt-get update >/dev/null
    apt-get install -y chromium >/dev/null
fi


# Golang
go version &> /dev/null
if [ $? -ne 0 ]; then
    echo "[*] Installing Golang..."
    if [[ "$ARCH_SUFFIX" == "amd64" ]]; then
        wget -q https://golang.org/dl/go1.24.2.linux-amd64.tar.gz
        tar -xvf go1.24.2.linux-amd64.tar.gz -C /usr/local >/dev/null
        rm -rf ./go1.24.2.linux-amd64.tar.gz >/dev/null
    elif [[ "$ARCH_SUFFIX" == "arm64" ]]; then
        wget -q https://golang.org/dl/go1.24.2.linux-arm64.tar.gz
        tar -xvf go1.24.2.linux-arm64.tar.gz -C /usr/local >/dev/null
        rm -rf ./go1.24.2.linux-arm64.tar.gz >/dev/null
    fi
    export GOROOT="/usr/local/go"
    export GOPATH="$homeDir/go"
    export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin:${PATH}"
else
    echo "[*] Skipping Golang install, already installed."
    echo "[!] Note: This may cause errors. If it does, check your Golang version and settings."
fi

# Go packages
echo "[*] Installing various Go packages..."
export GO111MODULE="on"
go install github.com/lc/gau@latest &>/dev/null
go install github.com/tomnomnom/gf@latest &>/dev/null
go install github.com/jaeles-project/gospider@latest &>/dev/null
go install github.com/projectdiscovery/katana/cmd/katana@latest &>/dev/null
go install github.com/sensepost/gowitness@latest &>/dev/null
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest &>/dev/null
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest &>/dev/null
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest &>/dev/null
go install github.com/tomnomnom/qsreplace@latest &>/dev/null
go install github.com/haccer/subjack@latest &>/dev/null
go install github.com/ffuf/ffuf/v2@latest &>/dev/null
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest &>/dev/null

# Nuclei-templates
nuclei -update-templates -update-template-dir $toolsDir/nuclei-templates &>/dev/null

# Custom Nuclei Templates
echo "[*] Cloning Custom Nuclei Templates..."
mkdir -p "$toolsDir/custom-nuclei-templates"
git clone https://github.com/geeknik/the-nuclei-templates.git "$toolsDir/custom-nuclei-templates/geeknik"
git clone https://github.com/h0tak88r/nuclei_templates.git "$toolsDir/custom-nuclei-templates/h0tak88r"


# Setup Rust
echo "[*] Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Enumrust
echo "[*] Installing Enumrust..."
# Creating a temp dir for cloning
mkdir -p "$toolsDir/enumrust_src"
git clone https://github.com/StartDemocracy/enumrust.git "$toolsDir/enumrust_src"
cd "$toolsDir/enumrust_src" || echo "Failed to cd to enumrust_src"
cargo build --release
cp target/release/enumrust /usr/local/bin/
cd "$toolsDir"
rm -rf "$toolsDir/enumrust_src"



# Subjack fingerprints file
echo "[*] Installing Subjack fingerprints..."
mkdir "$toolsDir/subjack"
wget -q https://raw.githubusercontent.com/haccer/subjack/master/fingerprints.json -O $toolsDir/subjack/fingerprints.json

# Temporary files wordlist
echo "[*] Installing ffuf wordlist..."
mkdir "$toolsDir/wordlists"
wget -q https://raw.githubusercontent.com/Bo0oM/fuzz.txt/master/fuzz.txt -O $toolsDir/wordlists/tempfiles.txt

# HTTPX
echo "[*] Installing HTTPX..."
wget -q https://github.com/projectdiscovery/httpx/releases/download/v1.6.10/httpx_1.6.10_linux_${ARCH_SUFFIX}.zip
if [[ -f "httpx_1.6.10_linux_${ARCH_SUFFIX}.zip" ]]; then
    unzip -j httpx_1.6.10_linux_${ARCH_SUFFIX}.zip -d /usr/bin/ httpx >/dev/null
    rm httpx_1.6.10_linux_${ARCH_SUFFIX}.zip
else
    echo "[!] HTTPX release not found for ${ARCH_SUFFIX} architecture. Skipping HTTPX installation."
fi

# Amass
echo "[*] Installing Amass..."
if [[ "$ARCH_SUFFIX" == "amd64" ]]; then
    wget -q https://github.com/owasp-amass/amass/releases/download/v4.2.0/amass_Linux_amd64.zip
    unzip -q amass_Linux_amd64.zip
    mv amass_Linux_amd64 amass
    rm amass_Linux_amd64.zip
elif [[ "$ARCH_SUFFIX" == "arm64" ]]; then
    wget -q https://github.com/owasp-amass/amass/releases/download/v4.2.0/amass_Linux_arm64.zip
    if [[ -f "amass_Linux_arm64.zip" ]]; then
        unzip -q amass_Linux_arm64.zip
        mv amass_Linux_arm64 amass
        rm amass_Linux_arm64.zip
    else
        echo "[!] Amass release not found for ARM64 architecture. Skipping Amass installation."
    fi
fi
if [[ -d "$toolsDir/amass" ]]; then
    cp $toolsDir/amass/amass /usr/bin/amass
fi

# Gf-patterns
echo "[*] Installing Gf-patterns..."
git clone -q https://github.com/1ndianl33t/Gf-Patterns
mkdir "$homeDir"/.gf
cp "$toolsDir"/Gf-Patterns/*.json "$homeDir"/.gf

# nrich
echo "[*] Installing nrich..."
if [[ "$ARCH_SUFFIX" == "amd64" ]]; then
    wget -q https://gitlab.com/api/v4/projects/33695681/packages/generic/nrich/latest/nrich_latest_amd64.deb
    dpkg -i nrich_latest_amd64.deb &>/dev/null
    rm nrich_latest_amd64.deb
elif [[ "$ARCH_SUFFIX" == "arm64" ]]; then
    wget -q https://gitlab.com/api/v4/projects/33695681/packages/generic/nrich/latest/nrich_latest_arm64.deb
    if [[ -f "nrich_latest_arm64.deb" ]]; then
        dpkg -i nrich_latest_arm64.deb &>/dev/null
        rm nrich_latest_arm64.deb
    else
        echo "[!] nrich release not found for ARM64 architecture. Skipping nrich installation."
    fi
fi

# Persist configured environment variables via global profile.d script
echo "[*] Setting environment variables..."
if [ -f "$homeDir"/.bashrc ]
then
    { echo "export GOROOT=/usr/local/go";
    echo "export GOPATH=$homeDir/go";
    echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin';
    echo "export GO111MODULE=on"; 
    echo 'export PATH=$PATH:$HOME/.cargo/bin'; } >> "$homeDir"/.bashrc
    source "$homeDir"/.bashrc
fi

if [ -f "$homeDir"/.zshrc ]
then
    { echo "export GOROOT=/usr/local/go";
    echo "export GOPATH=$homeDir/go";
    echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin';
    echo "export GO111MODULE=on";
    echo 'export PATH=$PATH:$HOME/.cargo/bin'; } >> "$homeDir"/.zshrc
fi

# Cleanup
apt remove unzip -y &>/dev/null
cd "$baseDir" || { echo "Something went wrong"; exit 1; }

echo "[*] SETUP FINISHED."
exit 0
