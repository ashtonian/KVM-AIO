# KVM-AIO

This is a set of notes and highlights for my aio kvm setup using Ubuntu 22.04 LTS w/5.17.x, Win 11 and Mac OS Monteray setup. 


## Hardware
TODO

## Setup Guide

This is a derivative of [OSX-KVM](https://github.com/kholia/OSX-KVM).


### Init

```sh

# Install Dependencies 
sudo apt-get swtpm libtpms0 install rsync dkms qemu uml-utilities virt-manager git \
    wget libguestfs-tools p7zip-full  make dmg2img -y

# Get latest opencore efi 
cd ~
wget https://github.com/thenickdude/KVM-Opencore/releases/download/v17/OpenCoreEFIFolder-v17.zip
unzip OpenCoreEFIFolder-v17.zip

cd ~
git clone --depth 1 --recursive https://github.com/Ashtonian/KVM-AIO
cd KVM-AIO

# intel fix see OSX-KVM
echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs
sudo cp kvm.conf /etc/modprobe.d/kvm.conf  # for intel boxes only, after cloning the repo below

# permissions
sudo usermod -aG kvm $(whoami)
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG input $(whoami)

# fetch and create initial images
./scripts/fetch-macOS-v2.py
dmg2img -i BaseSystem.dmg BaseSystem.img
qemu-img create -f qcow2 mac_hdd_ng.img 128G

# sync efi folders
rsync -avh --progress ~/EFI/ ./EFI
./scripts/opencore-image-ng.sh --cfg cfg.plist --img OpenCore.qcow2

# add machine to virt manager
virt-xml-validate macOS.xml
virsh --connect qemu:///system define macOS.xml

# permissions
sudo setfacl -m u:libvirt-qemu:rx /home/$USER
sudo setfacl -R -m u:libvirt-qemu:rx /home/$USER/KVM-AIO

```

### Passthrough & Optimizations 


```sh
# verify IOMMU enabled 
dmesg | grep -i iommu
## ...
## ... DMAR: IOMMU enabled 
## ... 

# Get PCIE info check reset functionality 
./scripts/list_iommu_groups.sh 

	00:1f.5 Serial bus controller [0c80]: Intel Corporation Device [8086:7aa4] (rev 11)
IOMMU group 19
[RESET]	01:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Upstream Port of PCI Express Switch [1002:1478] (rev c1)
IOMMU group 20
[RESET]	02:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Downstream Port of PCI Express Switch [1002:1479]
IOMMU group 21
[RESET]	03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 22 [Radeon RX 6700/6700 XT / 6800M] [1002:73df] (rev c1)
IOMMU group 22
	03:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 HDMI Audio [Radeon RX 6800/6800 XT / 6900 XT] [1002:ab28]
IOMMU group 23
[RESET]	04:00.0 Non-Volatile memory controller [0108]: Sandisk Corp WD PC SN810 / Black SN850 NVMe SSD [15b7:5011] (rev 01)
IOMMU group 24
[RESET]	05:00.0 Ethernet controller [0200]: Aquantia Corp. Device [1d6a:14c0] (rev 03)
IOMMU group 25
[RESET]	07:00.0 Non-Volatile memory controller [0108]: Sandisk Corp WD PC SN810 / Black SN850 NVMe SSD [15b7:5011] (rev 01)
IOMMU group 26
[RESET]	08:00.0 Ethernet controller [0200]: Intel Corporation Ethernet Controller I225-V [8086:15f3] (rev 03)
IOMMU group 27
[RESET]	09:00.0 USB controller [0c03]: ASMedia Technology Inc. ASM2142 USB 3.1 Host Controller [1b21:2142]
IOMMU group 28
[RESET]	0a:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX210/AX211/AX411 160MHz [8086:2725] (rev 1a)
IOMMU group 29
[RESET]	0b:00.0 SATA controller [0106]: ASMedia Technology Inc. ASM1062 Serial ATA Controller [1b21:0612] (rev 02)
IOMMU group 30
[RESET]	0c:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Upstream Port of PCI Express Switch [1002:1478] (rev c1)
IOMMU group 31
[RESET]	0d:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Downstream Port of PCI Express Switch [1002:1479]

IOMMU group 32
[RESET]	0e:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600/6600 XT/6600M] [1002:73ff] (rev c1)
IOMMU group 33
	0e:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 HDMI Audio [Radeon RX 6800/6800 XT / 6900 XT] [1002:ab28]
IOMMU group 34
[RESET]	0f:00.0 USB controller [0c03]: ASMedia Technology Inc. ASM2142 USB 3.1 Host Controller [1b21:2142]
IOMMU group 35
[RESET]	10:00.0 Non-Volatile memory controller [0108]: Samsung Electronics Co Ltd NVMe SSD Controller SM981/PM981/PM983 [144d:a808]


CONFIG_FTRACE=y
CONFIG_KPROBES=y
CONFIG_PCI_QUIRKS=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_FUNCTION_TRACER=y

# update /etc/default/grub w/ pci isolation and intel init 
sudo nano /etc/default/grub 
## cat /etc/default/grub
## ...
## GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt vfio-pci.ids=1002:73df,1002:ab28,1002:73ff,1002:ab28,1b21:2142  quiet splash kvm.ignore_msrs=1 video=vesafb:off,efifb:off mitigations=off mds=off nopti isolcpus=0-19 nohz_full=0-19 pcie_aspm=off"
## ... 

# update vfio.conf
sudo nano /etc/modprobe.d/vfio.conf
## cat /etc/modprobe.d/vfio.conf
## options vfio-pci ids=1002:73df,1002:ab28,1002:73ff,1002:ab28,1b21:2142 disable_vga=1
## softdep radeon pre: vfio-pci
## softdep amdgpu pre: vfio-pci
## softdep nouveau pre: vfio-pci
## softdep drm pre: vfio-pci
## options kvm_amd avic=1

# Update limits.conf
sudo nano /etc/security/limits.conf
## cat /etc/security/limits.conf 
## ...
## @kvm            soft    memlock         unlimited
## @kvm            hard    memlock         unlimited
## @libvirt        soft    memlock         unlimited
## @libvirt        hard    memlock         unlimited
## ... 

# Fix permissions for /dev/vfio/1 - see OSX-KVM
sudo cp vfio-kvm.rules /etc/udev/rules.d/vfio-kvm.rules

sudo udevadm control --reload
sudo udevadm trigger

# Isolate IOMMU groups better 
## Not sure if this is needed for all 
sudo ./scripts/vfio-group.sh 21
sudo ./scripts/vfio-group.sh 22
sudo ./scripts/vfio-group.sh 27
sudo ./scripts/vfio-group.sh 34
sudo ./scripts/vfio-group.sh 32
sudo ./scripts/vfio-group.sh 33

# amd reset bug fix if needed
# install gnif vendor-reset 
cd ~
git clone https://github.com/gnif/vendor-reset
cd vendor-reset
sudo dkms install .
# load module 
echo 'vendor-reset' | sudo tee -a /etc/modules

# setup initial hook tool 
sudo mkdir -p /etc/libvirt/hooks
sudo wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu' -O /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
sudo service libvirtd restart


# update vm name and pci dev id in ./scripts/reset-hook.sh
sudo mkdir -p /etc/libvirt/hooks/qemu.d/macOS/start/begin
sudo cp ./scripts/reset-gpu.sh /etc/libvirt/hooks/qemu.d/macOS/start/begin/reset-gpu.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/macOS/start/begin


# update  grub and initramfs
sudo update-grub2
sudo update-initramfs -k all -u
sudo reboot now 


```

#### Update virt machine xml 

* Remove/add correct pcie devices 
** verify gpu match bus/function grouping ie if source is same bus different function pass that into vm the same
* Update CPU pinning group on core, l2/l3 as desired

Intel Core i9-12900KS (8P+8E) 
Only P cores are HT
 ```sh
ashtonian@city-17-nix:~$ lscpu -e
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE    MAXMHZ   MINMHZ      MHZ
  0    0      0    0 0:0:0:0          yes 5200.0000 800.0000 4910.201
  1    0      0    0 0:0:0:0          yes 5200.0000 800.0000 3200.000
  2    0      0    1 4:4:1:0          yes 5200.0000 800.0000 3200.000
  3    0      0    1 4:4:1:0          yes 5200.0000 800.0000 3200.000
  4    0      0    2 8:8:2:0          yes 5200.0000 800.0000 3200.000
  5    0      0    2 8:8:2:0          yes 5200.0000 800.0000 3200.000
  6    0      0    3 12:12:3:0        yes 5200.0000 800.0000 3200.000
  7    0      0    3 12:12:3:0        yes 5200.0000 800.0000 3200.000
  8    0      0    4 16:16:4:0        yes 5200.0000 800.0000 3200.000
  9    0      0    4 16:16:4:0        yes 5200.0000 800.0000 3200.000
 10    0      0    5 20:20:5:0        yes 5200.0000 800.0000 3200.000
 11    0      0    5 20:20:5:0        yes 5200.0000 800.0000 3200.000
 12    0      0    6 24:24:6:0        yes 5200.0000 800.0000 3200.000
 13    0      0    6 24:24:6:0        yes 5200.0000 800.0000 3200.000
 14    0      0    7 28:28:7:0        yes 5200.0000 800.0000 3200.000
 15    0      0    7 28:28:7:0        yes 5200.0000 800.0000 3200.000
 16    0      0    8 32:32:8:0        yes 3900.0000 800.0000 3200.000
 17    0      0    9 33:33:8:0        yes 3900.0000 800.0000 3200.000
 18    0      0   10 34:34:8:0        yes 3900.0000 800.0000 3200.000
 19    0      0   11 35:35:8:0        yes 3900.0000 800.0000 3200.000
 20    0      0   12 36:36:9:0        yes 3900.0000 800.0000 3200.000
 21    0      0   13 37:37:9:0        yes 3900.0000 800.0000 3200.000
 22    0      0   14 38:38:9:0        yes 3900.0000 800.0000 3200.000
 23    0      0   15 39:39:9:0        yes 3900.0000 800.0000 3200.000
```

#### Enable host netoworking 

```sh
ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp5s0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether f8:02:78:21:a5:0f brd ff:ff:ff:ff:ff:ff
3: enp8s0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether d8:bb:c1:a2:61:a1 brd ff:ff:ff:ff:ff:ff
4: wlp10s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DORMANT group default qlen 1000
    link/ether 80:45:dd:73:f4:47 brd ff:ff:ff:ff:ff:ff
5: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT group default qlen 1000
    link/ether 52:54:00:67:16:52 brd ff:ff:ff:ff:ff:ff
6: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT group default 
    link/ether 02:42:8b:29:bb:35 brd ff:ff:ff:ff:ff:ff

#can't use wifi without more hacks due to wifi ap protocol 
sudo tee -a /etc/netplan/01-kvmbridge.yaml > /dev/null <<EOT
network:
  ethernets:
    enp8s0:
      dhcp4: false
      optional: true
    enp5s0:
      dhcp4: false
      optional: true
  bons:
    bond0:
      interfaces:
      - enp5s0
      - enp8s0
      parameters:
        primary: enp5s0
        mode: active-backup
  bridges:
    br0:
      interfaces:
      - bond0
      dhcp4: true
      mtu: 1500
      parameters:
        stp: true
        forward-delay: 15
EOT

sudo netplan try
sudo netplan apply
sudo brctl addif br0 vnet0 # for adding with live vm 

virsh net-define ./kvmbridge.xml
virsh net-start host-bridge
virsh net-autostart host-bridge

# Select Bridge in vm config 
```

#### Update EFI w/usbmap

```sh
git clone https://github.com/corpnewt/ProperTree
sudo apt-get install python3-tk
python3 ./ProperTree/ProperTree.py



cd KVM-AIO
cp ./opencore-image-ng.sh ./
sudo ./opencore-image-ng.sh --cfg ./EFI/OC/config.plist --img OpenCore.qcow2 

```


#### Audio #### 

```sh
sudo apt-get install libpulse-dev git make cmake
git clone https://github.com/duncanthrax/scream.git
cd ./scream/Receivers/unix
mkdir build && cd build
cmake ..
make
cp ./scream /usr/bin/
```


#### Setup iServices

adjust smbios serial ect 
```
git clone https://github.com/corpnewt/GenSMBIOS
python3 ./GenSMBIOS/GenSMBIOS.py
```
Check ethernet is set as builtin and working via
* https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html#making-en0-show-as-built-in

## References 

* [OSX-KVM](https://github.com/kholia/OSX-KVM)
* [PCI passthrough via ovmf](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
* [KVM-Opencore](https://github.com/thenickdude/KVM-Opencore)
* [Roar](https://github.com/tyllj/Roar)
