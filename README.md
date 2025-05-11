# rk3399-am40-openwrt

Build [OpenWrt](https://openwrt.org) for rk3399-am40 using [Image Builder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder).  
Script can be used locally or via Github Actions.

<br/>
<br/>

## Build Locally
### Debian / Ubuntu
[Dependencies](https://openwrt.org/docs/guide-user/additional-software/imagebuilder#debianubuntumint) should be installed first.
```bash
git clone https://github.com/wn2try/rk3399-am40-openwrt.git --depth=1
cd rk3399-am40-openwrt
bash mkimg.sh
```
### Docker
`imagebuilder` container options: [OpenWrt Docker repository](https://github.com/openwrt/docker-openwrt/pkgs/container/imagebuilder#openwrt-docker-repository)  
Execute the code without `sudo` and not `root`, otherwise `--user root` has to be added to `docker run`.
```bash
git clone https://github.com/wn2try/rk3399-am40-openwrt.git --depth=1
cd rk3399-am40-openwrt
mkdir output
docker run -v ./input:/input -v ./output:/output -v ./mkimg.sh:/mkimg.sh \
       openwrt/imagebuilder:rockchip-armv8-24.10.1 /bin/bash /mkimg.sh
```

## Github Actions
`Actions`  -->  `workflows` (`RK3399-AM40 OpenWrt Builder`)  -->  `Run workflow`
 
<br/>
<br/>

## Explanations
`rk3399-am40`, this device is not supported officially. So the `dtb` and `u-boot` binaries have to be supplied manually, and a `kernel.bin` is created during the script run from the pre-built  `dtb` & `vmlinux` based on the configuration file `.its`. 
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

<br/>  

In addition to the traditional combined image `squashfs-sysupgrade.img.gz`, three other files to be created:
- `squashfs-rootfs.img.gz`, disk image contains only a rootfs partition in `squashfs`
- `rootfs.tar.gz` contains only files from the rootfs partition
- `kernel.tar.gz` contains `kernel.img` `boot.scr` `vmlinux` `dtb` `extlinux.conf`

<br/>

`boot / kernel` partition is `16MiB` in the combined image. And the `rootfs` partition is padded only to `64MiB`, which is sufficient for a `squashfs` root filesystem, as a separate partition for `overly` could be used. You may like to choose `f2fs` or `btrfs` for that partiton.
> [!NOTE]
> - Remember to transfer data generated after the first run from the overlayfs on `root` partition to the new `overlay` partition, refer to [this guide](https://openwrt.org/docs/guide-user/additional-software/extroot_configuration#transferring_data).  
> - Do not use `sysupgrade` `auc` `owut` if your device have a different partition table, otherwise it's likely to be overwritten.

<br/>

`u-boot` supports booting from `extlinux.conf`. A template is provided and is packed into the kernel tarball.
> [!NOTE]
> - `extlinux.conf` has a higher priority for `u-boot` and is easier to use than the legacy `boot script` (`boot.scr`).   
> - You can modify the boot-args easily, and  
> - choose to boot from a different kernel version or even another disk partition / file system with just few modifications.
>```bash
>menu title boot options, 3s to boot: OpenWrt
>default OpenWrt
>timeout 30
>prompt 1
>
>label OpenWrt
>  kernel /kernel.img
>  append root=/dev/mmcblk0p2 rw rootwait console=tty1 console=ttyS2,1500000
>
>label OpenWrt New
>  kernel /vmlinux
>  fdt /rk3399-am40.dtb
>  append root=/dev/mmcblk0p4 rw rootwait console=tty1 console=ttyS2,1500000
>```
