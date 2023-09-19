#!/bin/bash

root_access() {
    # Check if the script is running as root
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root access. please run as root."
        exit 1
    fi
}

# Function to check if wget is installed, and install it if not
check_dependencies() {
    if [ -x "$(command -v apt-get)" ]; then
        package_manager="apt-get"
    elif [ -x "$(command -v yum)" ]; then
        package_manager="yum"
    elif [ -x "$(command -v dnf)" ]; then
        package_manager="dnf"
    else
        echo "Unsupported package manager. Please install wget, lsof, and iptables manually."
        exit 1
    fi

    if ! command -v wget &> /dev/null; then
        echo "wget is not installed. Installing..."
        sudo $package_manager install wget -y
    fi

    if ! command -v lsof &> /dev/null; then
        echo "lsof is not installed. Installing..."
        sudo $package_manager install lsof -y
    fi

    if ! command -v iptables &> /dev/null; then
        echo "iptables is not installed. Installing..."
        sudo $package_manager install iptables -y
    fi
    
    if ! command -v unzip &> /dev/null; then
        echo "unzip is not installed. Installing..."
        sudo $package_manager install unzip -y
    fi
    
    if ! command -v gcc &> /dev/null; then
        echo "gcc is not installed. Installing..."
        sudo $package_manager install gcc -y
    fi
}

#Check installed service
check_installed() {
    if [ -f "/etc/systemd/system/faketunnel.service" ]; then
        echo "The service is already installed."
        exit 1
    fi
}

#Check installed service
check_installed2() {
    if [ -f "/etc/systemd/system/faketunnelsingle.service" ]; then
        echo "The service is already installed."
        exit 1
    fi
}

# Function to download and install FTT
install_ftt() {
    wget "https://raw.githubusercontent.com/radkesvat/FakeTlsTunnel/master/install.sh" -O install.sh && chmod +x install.sh && bash install.sh 
}

# Function to configure arguments based on user's choice single port
configure_arguments2() {
    read -p "Which server do you want to use? (Enter '1' for Iran or '2' for Kharej) : " server_choice
    read -p "Please Enter Port (Please choose the same port on both servers): " port
    read -p "Please Enter SNI (default : google.com): " sni
    sni=${sni:-google.com}

    if [ "$server_choice" == "2" ]; then
        read -p "Please Enter Password (Please choose the same password on both servers): " password
        arguments="--server --lport:443 --toip:127.0.0.1 --toport:$port --sni:$sni --password:$password --terminate:24"
    elif [ "$server_choice" == "1" ]; then
        read -p "Please Enter (Kharej IP) : " server_ip
        read -p "Please Enter Password (Please choose the same password on both servers): " password
        arguments="--tunnel --lport:$port --toip:$server_ip  --toport:443 --sni:$sni --password:$password --terminate:24"
    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi
    echo "successfull . arguments: $arguments"
}

# Function to configure arguments based on user's choice Multiport
configure_arguments() {
    read -p "Which server do you want to use? (Enter '1' for Iran or '2' for Kharej) : " server_choice
    read -p "Please Enter SNI (default : splus.ir): " sni
    sni=${sni:-google.com}

    if [ "$server_choice" == "2" ]; then
        read -p "Please Enter Password (Please choose the same password on both servers): " password
        arguments="--server --lport:443 --toip:127.0.0.1 --toport:2000 --password:$password --multiport --sni:$sni --terminate:24"
    elif [ "$server_choice" == "1" ]; then
        read -p "Please Enter (Kharej IP) : " server_ip
        read -p "Please Enter Password (Please choose the same password on both servers): " password
        arguments="--tunnel --lport:23-65535 --toip:$server_ip --toport:443 --password:$password --sni:$sni --terminate:24"
    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi
    echo "successfull .arguments: $arguments"
}

# Function to handle installation single port
install_single() {
    root_access
    check_dependencies
    check_installed2
    install_ftt
    # Change directory to /etc/systemd/system
    cd /etc/systemd/system
    configure_arguments2
    # Create a new service file named faketunnel.service
    cat <<EOL > faketunnelsingle.service
[Unit]
Description=fake tls tunnel service single

[Service]
User=root
WorkingDirectory=/root
ExecStart=/root/FTT $arguments
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemctl daemon and start the service
    sudo systemctl daemon-reload
    sudo systemctl start faketunnelsingle.service
    sudo systemctl enable faketunnelsingle.service
}

# Function to handle uninstallation single
uninstall_single() {
    # Check if the service is installed
    if [ ! -f "/etc/systemd/system/faketunnelsingle.service" ]; then
        echo "The service is not installed."
        return
    fi

    # Stop and disable the service
    sudo systemctl stop faketunnelsingle.service
    sudo systemctl disable faketunnelsingle.service

    # Remove service file
    sudo rm /etc/systemd/system/faketunnelsingle.service
    sudo systemctl reset-failed
    sudo rm FTT
    sudo rm install.sh

    echo "Uninstallation completed successfully."
}

# Function to handle installation
install_multi() {
    root_access
    check_dependencies
    check_installed
    install_ftt
    # Change directory to /etc/systemd/system
    cd /etc/systemd/system
    configure_arguments
    # Create a new service file named faketunnel.service
    cat <<EOL > faketunnel.service
[Unit]
Description=fake tls tunnel service

[Service]
User=root
WorkingDirectory=/root
ExecStart=/root/FTT $arguments
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemctl daemon and start the service
    sudo systemctl daemon-reload
    sudo systemctl start faketunnel.service
    sudo systemctl enable faketunnel.service
}

# Function to handle uninstallation multi
uninstall_multi() {
    # Check if the service is installed
    if [ ! -f "/etc/systemd/system/faketunnel.service" ]; then
        echo "The service is not installed."
        return
    fi

    # Stop and disable the service
    sudo systemctl stop faketunnel.service
    sudo systemctl disable faketunnel.service

    # Remove service file
    sudo rm /etc/systemd/system/faketunnel.service
    sudo systemctl reset-failed
    sudo rm FTT
    sudo rm install.sh

    echo "Uninstallation completed successfully."
}

update_services() {
    # Get the current installed version of FTT
    installed_version=$(./FTT -v 2>&1 | grep -o '"[0-9.]*"')

    # Fetch the latest version from GitHub releases
    latest_version=$(curl -s https://api.github.com/repos/radkesvat/FakeTlsTunnel/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d":" -f2 | sed 's/["V ]//g' | sed 's/^/"/;s/$/"/')

    # Compare the installed version with the latest version
    if [[ "$latest_version" > "$installed_version" ]]; then
        echo "Updating to $latest_version (Installed: $installed_version)..."
        if sudo systemctl is-active --quiet faketunnel.service; then
            echo "faketunnel.service is active, stopping..."
            sudo systemctl stop faketunnel.service > /dev/null 2>&1
        elif sudo systemctl is-active --quiet faketunnelsingle.service; then
            echo "faketunnelsingle.service is active, stopping..."
            sudo systemctl stop faketunnelsingle.service > /dev/null 2>&1
        fi

        # Download and run the installation script
        wget "https://raw.githubusercontent.com/radkesvat/FakeTlsTunnel/master/install.sh" -O install.sh && chmod +x install.sh && bash install.sh

        # Start the previously active service
        if sudo systemctl is-active --quiet faketunnel.service; then
            echo "Restarting faketunnel.service..."
            sudo systemctl start faketunnel.service > /dev/null 2>&1
        elif sudo systemctl is-active --quiet faketunnelsingle.service; then
            echo "Restarting faketunnelsingle.service..."
            sudo systemctl start faketunnelsingle.service > /dev/null 2>&1
        fi

        echo "Service updated and restarted successfully."
    else
        echo "You have the latest version ($installed_version)."
    fi
}

compile() {
    # Detect the operating system
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        # Linux operating system
        if [[ "$(uname -m)" == "x86_64" ]]; then
            # 64-bit architecture
            file_url="https://github.com/nim-lang/nightlies/releases/download/latest-version-2-0/linux_x64.tar.xz"
        elif [[ "$(uname -m)" == "x86" ]]; then
            # 32-bit architecture
            file_url="https://github.com/nim-lang/nightlies/releases/download/latest-version-2-0/linux_x32.tar.xz"
        elif [[ "$(uname -m)" == "aarch64" ]]; then
            # arm64 architecture
            file_url="https://github.com/nim-lang/nightlies/releases/download/latest-version-2-0/linux_arm64.tar.xz"
        elif [[ "$(uname -m)" == "armv7l" ]]; then
            # armv7l architecture
            file_url="https://github.com/nim-lang/nightlies/releases/download/latest-version-2-0/linux_armv7l.tar.xz"
        else
            echo "Unknown architecture!"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS operating system
        file_url="https://github.com/nim-lang/nightlies/releases/download/latest-version-2-0/macosx_x64.tar.xz"
    else
        echo "Unsupported operating system!"
        exit 1
    fi

    # Download the file based on the operating system and architecture
    wget "$file_url"
    tar -xvf "$(basename "$file_url")"

    # Add the Nim path to PATH
    export PATH="$PWD/nim-2.0.1/bin:$PATH"

    # Clone the project
    git clone https://github.com/radkesvat/ReverseTlsTunnel.git

    # Navigate to the project directory
    cd ReverseTlsTunnel

    # Install and compile the project
    nim install
    nim build

    # Copy the FTT file from dist directory to the current directory
    cp dist/FTT "$PWD/"

    # Successful message
    echo "Project compiled successfully."
    # Display the path of the FTT file
    echo "FTT file is located at: $PWD/FTT"
}

#ip & version
myip=$(hostname -I | awk '{print $1}')
version=$(./FTT -v 2>&1 | grep -o 'version="[0-9.]*"')

# Main menu
clear
echo "By --> Peyman * Github.com/Ptechgithub * "
echo "Your IP is: ($myip) "
echo ""
echo " --------#- Fake Tls Tunnel -#--------"
echo "1) Install (Single port)"
echo "2) Uninstall (Single port)"
echo " ----------------------------"
echo "3) Install (Multi port)"
echo "4) Uninstall (Multi port)"
echo " ----------------------------"
echo "5) Update FTT"
echo "6) Compile FTT"
echo "0) Exit"
echo " --------------$version--------------"
read -p "Please choose: " choice

case $choice in
    1)
        install_single
        ;;
    2)
        uninstall_single
        ;;
    3)
        install_multi
        ;;
    4)
        uninstall_multi
        ;;
    5)
        update_services
        ;;
    6)
        compile
        ;;
    0)   
        exit
        ;;
    *)
        echo "Invalid choice. Please try again."
       ;;
esac
