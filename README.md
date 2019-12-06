# Mantissa
A Qt based browser made with love.

## Dependencies:
### Debian & Ubuntu
On Debian and Ubuntu, mantissa depends on the following packages:

`sudo apt install build-essential cmake qtbase5-dev qt5-default qtwebengine5-dev`

#### Void Linux
Install the following:

`sudo xbps-install -S gcc make cmake qt5-webengine-devel qt5-webchannel-devel qt5-declarative-devel qt5-location-devel`

#### FreeBSD
Install the following:

`pkg install cmake qt5-buildtools qt5-webengine`

## Build instructions.
Inside the cloned git repository:

```bash
mkdir build && cd build
cmake ../
make
sudo make install
```
