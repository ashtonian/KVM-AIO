# KVM-AIO

This is a set of notes and highlights for my aio kvm setup using Ubuntu 22.04 LTS w/5.17.x, Win 11 and Mac OS Monteray setup. 


## Hardware
TODO

## Setup Guide

This is a derivative of [OSX-KVM](https://github.com/kholia/OSX-KVM).


### Init

```sh

# Install Dependencies 
sudo apt-get install rsync qemu uml-utilities virt-manager git \
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

## ...
## IOMMU group 18
## [RESET]	01:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Upstream Port of PCI Express Switch [1002:1478] (rev c1)
## IOMMU group 19
## [RESET]	02:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Downstream Port of PCI Express Switch [1002:1479]
## IOMMU group 20
## [RESET]	03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 22 [Radeon RX 6700/6700 XT / 6800M] [1002:73df] (rev c1)
## IOMMU group 21
## 	03:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 HDMI Audio [Radeon RX 6800/6800 XT / 6900 XT] [1002:ab28]
## IOMMU group 22
## [RESET]	04:00.0 Non-Volatile memory controller [0108]: Sandisk Corp WD PC SN810 / Black SN850 NVMe SSD [15b7:5011] (rev 01)
## IOMMU group 23
## [RESET]	06:00.0 Non-Volatile memory controller [0108]: Sandisk Corp WD PC SN810 / Black SN850 NVMe SSD [15b7:5011] (rev 01)
## IOMMU group 24
## [RESET]	07:00.0 Ethernet controller [0200]: Intel Corporation Ethernet Controller I225-V [8086:15f3] (rev 03)
## IOMMU group 25
## [RESET]	08:00.0 USB controller [0c03]: ASMedia Technology Inc. ASM2142 USB 3.1 Host Controller [1b21:2142]
## IOMMU group 26
## [RESET]	09:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX210/AX211/AX411 160MHz [8086:2725] (rev 1a)
## IOMMU group 27
## [RESET]	0a:00.0 SATA controller [0106]: ASMedia Technology Inc. ASM1062 Serial ATA Controller [1b21:0612] (rev 02)
## IOMMU group 28
## [RESET]	0b:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Baffin [Radeon RX 550 640SP / RX 560/560X] [1002:67ff] (rev cf)
## 	0b:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Baffin HDMI/DP Audio [Radeon RX 550 640SP / RX 560/560X] [1002:aae0]
## IOMMU group 29
## [RESET]	0d:00.0 Non-Volatile memory controller [0108]: Samsung Electronics Co Ltd NVMe SSD Controller SM981/PM981/PM983 [144d:a808]



# update /etc/default/grub w/ pci isolation and intel init 
sudo nano /etc/default/grub 
## cat /etc/default/grub
## ...
## GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt vfio-pci.ids=1002:73df,1002:ab28,1002:67ff,1002:aae0,1b21:2142  quiet splash kvm.ignore_msrs=1 video=vesafb:off,efifb:off"
## ... 

# update vfio.conf
sudo nano /etc/modprobe.d/vfio.conf
## cat /etc/modprobe.d/vfio.conf
## options vfio-pci ids=1002:73df,1002:ab28,1002:67ff,1002:aae0,1b21:2142 disable_vga=1
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
sudo ./scripts/vfio-group.sh 20
sudo ./scripts/vfio-group.sh 21
sudo ./scripts/vfio-group.sh 25
sudo ./scripts/vfio-group.sh 28

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



## References 

* [OSX-KVM](https://github.com/kholia/OSX-KVM)
* [PCI passthrough via ovmf](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
* [KVM-Opencore](https://github.com/thenickdude/KVM-Opencore)
* [Roar](https://github.com/tyllj/Roar)

## TODO

* [Huge pages](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Dynamic_huge_pages)

Reference
```
hugetlbfs /dev/hugepages hugetlbfs defaults /etc/fstab 
```

* Update OVMF see notes
* amd reset bug 
* ROM via VBFlash 