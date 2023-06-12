if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
echo nameserver 8.8.8.8 | sudo tee /etc/resolv.conf

apt-get update -y

REQUIRED_PKG="unzip"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  echo "Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="wget"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  echo "Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
fi

pkill FTT
printf  "\n"
printf  "\n"


echo "downloading FakeTlsTunnel"

printf  "\n"



wget "https://github.com/radkesvat/FakeTlsTunnel/releases/download/V10.1/v10.1_linux_amd64.zip" -O v10.1_linux_amd64.zip
unzip -o v10.1_linux_amd64.zip
chmod +x FTT
rm v10.1_linux_amd64.zip

echo "finished."

printf  "\n"