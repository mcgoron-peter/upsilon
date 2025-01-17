Upsilon docker development environment setup

# Docker Guide

This guide is tailored toward a Debian-based machine (and tested on Debian 12).
However, because most of the build process occurs within Docker containers,
this guide should be easily adopted to run in nearly any modern Linux environment.

# Setup steps

Do all of the following in the `build` folder.

## Installing OpenFPGALoader

Install [openFPGALoader][1]. If this program is not in your repositories,
run `make openFPGALoader` to fetch and build the program. This will install
openFPGALoader locally.

Even if you install openFPGALoader locally, there are some files (udev rules)
that must be installed with administrative privleges. Check the documentation
for openFPGALoader.

[1]: https://trabucayre.github.io/openFPGALoader/index.html

## Setup Rootless Docker

Docker allows you to run programs in containers, which are isolated
environments. Build environments can be set up automatically, and re-setup
whenever needed.

To install Docker, run:
```bash
sudo apt install docker.io docker-compose
```

Next, using [this guide][2], create a `docker` group and add your user to
that group. This will allow you to run docker commands without needing to run
them as root each time.

If you have issues with docker, try adding to `~/.config/docker/daemon.json`

    {
       "storage-driver": "fuse-overlayfs"
    }


## Download and Install Python3

Install `python3-venv` (or `python3-virtualenv`) and `python3-pip`:
```bash
sudo apt install python3-venv python3-pip
```

## Clone External Repositories

Run `make clone`. You may need to download the upsilon repositories
and put them in the same folder as the Makefile.

Note: If `make` is not already installed, you can install it by running the following
command:
```bash
sudo apt install build-essential
```

## Setup Network

Plug in your router/switch to an ethernet port on your computer. If your
computer is usually wired to the network, you will need another ethernet
port (a PCI card is ideal, but a USB-Ethernet port works).

Set the ethernet port to static ip `192.168.2.100/24`, netmask `255.255.255.0`,
gateway `192.168.2.1`. Make sure this is not the default route. Make sure
to adjust your firewall to allow traffic on the `192.168.2.0/24` range.

If your local network already uses the `192.168.2.0/24` range, then you must
modify `upsilon/firmware/soc.py` to use different IPs. You must rebuild the
SoC after doing this.

## Setup Images

Run `make images` to create all docker images.

## Setup and Run Containers

For `NAME` in `hardware`, `opensbi`, `buildroot`:

1. Run `make $NAME-container` to build the container. You usually only need
   to do this once.
2. If the container already exists, do `docker container start upsilon-$NAME`.
3. Run `make $NAME-copy` to copy Upsilon's code into the container.
4. Run `make $NAME-execute` to build the data.
5. Run `make $NAME-get` to retrieve the build artifacts.

If you do not delete the container you can run the following when you need to rebuild:

```bash
make $NAME-copy $NAME-execute $NAME-get
```

If you need shell access, run `make $NAME-shell`.

Run `make $NAME-clean` to delete the container.

## Launch TFTP Server

Install py3tftp (`pip3 install --user py3tftp`). Then run `make tftp` to
launch the TFTP server. Keep this terminal open.

## Flash FPGA

Plug in your FPGA into the USB slot. If you have installed openFPGALoader
by your package manager, run `make flash`. If you compiled openFPGALoader using
`make openFPGALoader`, the makefile will automatically use this instance. Otherwise,
it will attempt to use the openFPGALoader version installed through the package manager.

In a second you should see messages in the TFTP terminal. This means your
controller is sucessfully connected to your computer.

## SSH Access

Add the following to your SSH config:

	Host upsilon
		HostName 192.168.2.50
		StrictHostKeyChecking no
		UserKnownHostsFile /dev/null
		IdentityFile upsilon_key
		User root
		LogLevel QUIET

Then copy the file `build/upsilon_key` to `$HOME/.ssh`.

When the FPGA is connected you can access it with `ssh upsilon` (password
`upsilon`).

Wait about a minute for Linux to boot.

## Launch FPGA Shell (Optional)

If you cannot access the FPGA through SSH, you can launch a shell through
UART.

You will need to install [LiteX](https://github.com/enjoy-digital/litex).
Download and run `litex_setup.py`.

Run `litex_term /dev/ttyUSB1`. You should get messages in the window with
the TFTP server that the FPGA has connected to the server. Eventually you
will get a login prompt (username `root` password `upsilon`).

## Copy Library

Run `make copy` to copy the Micropython Upsilon library to the FPGA. After
this the modules `comm` and `mmio` are available when running scripts in
`/root`.
