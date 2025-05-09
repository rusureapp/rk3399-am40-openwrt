#! /bin/bash
set -eu
#set -x


openwrtver=${openwrtver:-24.10.1}
platform=${platform:-rockchip}
subtarget=${subtarget:-armv8}

soc=${soc:-rk3399}
model=${model:-am40}
vendor=${soc^^}
device=${soc}_${model}

rootfs_size=${rootfs_size:-64}
create_ext4fs=${create_ext4fs:-NO}
disable_services=${disable_services:-}


cd $(dirname "$0")
rootpath="$(pwd)"
dtbdir=${rootpath}/input/kernel/dtb
itsdir=${rootpath}/input/kernel/its
ubootdir=${rootpath}/input/u-boot
filesdir=${rootpath}/input/files

pkgpath=${rootpath}/input/packages/packages.txt

outdir=${rootpath}/output

builder_site=https://downloads.openwrt.org



## download imagebuilder
downloadurl=${builder_site}/releases/${openwrtver}/targets/${platform}/${subtarget}/openwrt-imagebuilder-${openwrtver}-${platform}-${subtarget}.Linux-x86_64.tar.zst
if [ ! -d builder ]; then
	wget -O - ${downloadurl} | tar --zstd -xf - 
	mv *imagebuilder*-x86_64 builder
fi
cd builder

[ ! -d tmp ] && mkdir tmp


## device-kernel.bin
dtbpath=$(ls ${dtbdir}/*${model}*.dtb 2>/dev/null | head -1)
kerneldir=build_dir/target-aarch64_generic_musl/linux-${platform}_${subtarget}
if [ ! -e ${kerneldir}/${device}-kernel.bin ]; then
	## create kernel bin: (vmlinux -> lzma) + dtb -> fit 

	if [[ -z ${dtbpath} ]]; then
		echo "No dtb file in ${dtbdir}, unable to create kernel bin, exit."
		exit 1
	fi
	itspath=$(ls $itsdir/*${model}*.its | head -1); [[ -z ${itspath} ]] && exit 1

	staging_dir/host/bin/lzma e ${kerneldir}/vmlinux tmp/vmlinux.lzma -lc1 -lp2 -pb2

	kernelver=$(cd ${kerneldir}; ls -d linux-*)
	cp ${itspath} tmp/
	sed -e "s|kerneldesc|ARM64 OpenWrt ${kernelver^}|" \
		-e "s|kernelpath|vmlinux.lzma|" \
		-e "s|dtbpath|${dtbpath}|" \
		-i tmp/*.its

	echo 'create kernel.bin: '
	PATH=${kerneldir}/${kernelver}/scripts/dtc:$PATH \
	staging_dir/host/bin/mkimage -f tmp/*.its ${kerneldir}/${device}-kernel.bin
	echo ' '
fi


## add build target
makefile=target/linux/${platform}/image/${subtarget}.mk
modelexist=$(grep -ic "${model}" ${makefile}) || true
if [ ${modelexist} -eq 0 ]; then
cat << EOF >> ${makefile}

define Device/${device}
  DEVICE_VENDOR := ${vendor}
  DEVICE_MODEL := ${model^^}
  SOC := ${soc}
  IMAGES := sysupgrade.img.gz rootfs.img.gz
  IMAGE/rootfs.img.gz := append-rootfs | pad-to \$(ROOTFS_PARTSIZE) | gzip
endef
TARGET_DEVICES += ${device}
EOF
fi


## add board profile
prof=.targetinfo
profexist=$(grep -ic "${model}" ${prof}) || true
if [ ${profexist} -eq 0 ]; then
	profile="\nTarget-Profile: DEVICE_${device}\nTarget-Profile-Name: ${vendor} ${model^^}\nTarget-Profile-Packages: \nTarget-Profile-hasImageMetadata: 1\nTarget-Profile-SupportedDevices: ${soc}\,${model}\n@@\n"
	sed "/Target: ${platform}\/${subtarget}/,/@@/ s/@@/@@\n${profile}/" -i ${prof}
	[ -e .profiles.mk ] && rm .profiles.mk
fi


## do not create EXT4FS
if [ ${create_ext4fs} == NO ]; then
	sed "s/CONFIG_TARGET_ROOTFS_EXT4FS=y/# CONFIG_TARGET_ROOTFS_EXT4FS is not set/" -i .config
fi


## copy u-boot bin
ubootpath=$(ls $ubootdir/*u-boot*.bin | head -1); [ -z ${ubootpath} ] && exit 1
cp ${ubootpath} staging_dir/target-aarch64_generic_musl/image/${model}-${soc}-u-boot-${platform}.bin


## files to include
dirs=$(ls -d ${filesdir}/*/ 2>/dev/null) || true
if [[ ${dirs} ]]; then
	[ ! -d files ] && mkdir files
	cp -rf ${dirs} files/ 
fi


## packages
pkgadd=$(sed -n '/^add:/ {s/add: //; p;}' ${pkgpath})
pkgremove=$(sed -n '/^remove:/ {s/ / -/g; s/remove: //; p;}' ${pkgpath})


## prepare output dir
if [[ -d ${outdir} ]]; then
	rm -r ${outdir}/* 2>/dev/null || true
else
	[[ ${outdir} ]] && mkdir ${outdir}
fi


## build
export CONFIG_TARGET_ROOTFS_TARGZ=y
make image \
PROFILE="${device}" \
PACKAGES="${pkgadd} ${pkgremove}" \
DISABLED_SERVICES="${disable_services}" \
FILES="files" \
ROOTFS_PARTSIZE=${rootfs_size} \
BIN_DIR="${outdir}/"


## rename outputs
cd ${outdir}
for name in *${platform}-${subtarget}*; do
	mv ${name} $(echo ${name} | sed "s/${platform}-${subtarget}-//")
done


## create kernel tarball
cp -r ${rootpath}/builder/${kerneldir}/tmp/openwrt-${openwrtver}-${platform}-${subtarget}-${soc}_${model}-squashfs-sysupgrade.img.gz.boot kernel
cp ${rootpath}/builder/${kerneldir}/vmlinux kernel/
[[ ${dtbpath} ]] && cp ${dtbpath} kernel/
extlinuxdir=${rootpath}/input/kernel/extlinux
[ -d ${extlinuxdir} ] && cp -r ${extlinuxdir} kernel/
kernelnm=$(ls *rootfs.tar.gz | sed 's/rootfs/kernel/')
tar -czf ${kernelnm} -C kernel/ .
rm -r kernel
rm sha256sums
sha256sum *.* > sha256sums


echo ' '
echo 'files created:'
ls -lh ${outdir}

echo "Done."
