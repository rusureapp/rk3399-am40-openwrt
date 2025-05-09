# rk3399-am40-openwrt

Build [OpenWrt](https://openwrt.org) for rk3399-am40 using [Image Builder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder).  
Script can be used locally or via Github Action.

---
## Build Locally
### Debian / Ubuntu
Ensure [dependencies](https://openwrt.org/docs/guide-user/additional-software/imagebuilder#debianubuntumint) are installed prior to build.
```bash
git clone https://github.com/wn2try/rk3399-am40-openwrt.git --depth=1
cd rk3399-am40-openwrt
bash mkimg.sh
```
### Docker
`imagebuilder` container options: [OpenWrt Docker repository](https://github.com/openwrt/docker-openwrt/pkgs/container/imagebuilder#openwrt-docker-repository)  
Execute the code without `sudo` and not root, otherwise `--user root` has to be added to `docker run`.
```bash
git clone https://github.com/wn2try/rk3399-am40-openwrt.git --depth=1
cd rk3399-am40-openwrt
mkdir output
docker run -v ./input:/input -v ./output:/output -v ./mkimg.sh:/mkimg.sh \
       openwrt/imagebuilder:rockchip-armv8-24.10.1 /bin/bash /mkimg.sh
```

## Github Action
`Actions`  -->  `workflows` (`RK3399-AM40 OpenWrt Builder`)  -->  `Run workflow` (change version)

---
## Explanations
`rk3399-am40` this device is not supported officially, so the `dtb` and `u-boot` binaries have to be supplied manually, as well as the `kernel.bin` which is built by the script. 
```bash
.
├── input
│   ├── files
│   │   └── etc
│   │       └── uci-defaults
│   │           └── 99-custom-openwrt
│   ├── kernel
│   │   ├── dtb
│   │   │   └── rk3399-am40-novideo_v6.14.dtb
│   │   ├── extlinux
│   │   │   └── extlinux.conf.template
│   │   └── its
│   │       └── openwrt-kernel-img_rk3399-am40.its
│   ├── packages
│   │   └── packages.txt
│   └── u-boot
│       └── u-boot-rockchip-rk3399-am40_v2025.04.bin
└── mkimg.sh
```
- Additional files to be supplied in `input/files`

- Specify the packages to be added or removed in `input/packages/packages.txt`

- In addition to the traditional combined image `squashfs-sysupgrade.img.gz`, three other files to be created:
	- `squashfs-rootfs.img.gz` disk image contains only a rootfs partition in `squashfs`
	- `rootfs.tar.gz` contains only files from the rootfs partition
	- `kernel.tar.gz` contains `kernel.img` `boot.scr` `vmlinux` `dtb` `extlinux.conf`

- `root partition` is padded to `64MiB`, which is sufficient for a `squashfs` root filesystem, as a separate partition for `overly` is recommended. You may like to choose `f2fs` or `btrfs` for that partiton and use any mount options.

> [!NOTE]
> `u-boot` supports booting from `extlinux.conf`. A template is provided and will be packed into the kernel tarball.  
>	- `extlinux.conf` has a higher priority and is easier to use than the legacy `boot script` (`boot.scr`).   
>	- You can modify the boot-args easily, and  
>	- choose to boot from a different kernel version or even another disk partition with just few modifications.

