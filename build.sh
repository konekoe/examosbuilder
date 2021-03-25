#!/bin/bash

set -e -u

iso_name=examlive
iso_label="EXAMOS_$(date +%Y%m)"
iso_version=$(date +%Y.%m.%d)
install_dir=arch
work_dir=work
out_dir=out
gpg_key=
examos_publisher="Aalto University <http://examos.aalto.fi>"
examos_application="ExamOS Live USB/DVD"
testbuild=""
unsiged_bootloader=""
crypted_partitions=""
standalone=""

arch=$(uname -m)
verbose=""
script_path="$( cd -P "$( dirname "$(readlink -f "$0")" )" && pwd )"



SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"



_usage ()
{
    echo "usage ${0} [options]"
    echo
    echo " General options:"
    echo "    -N <iso_name>      Set an iso filename (prefix)"
    echo "                        Default: ${iso_name}"
    echo "    -V <iso_version>   Set an iso version (in filename)"
    echo "                        Default: ${iso_version}"
    echo "    -L <iso_label>     Set an iso label (disk label)"
    echo "                        Default: ${iso_label}"
    echo "    -D <install_dir>   Set an install_dir (directory inside iso)"
    echo "                        Default: ${install_dir}"
    echo "    -w <work_dir>      Set the working directory"
    echo "                        Default: ${work_dir}"
    echo "    -o <out_dir>       Set the output directory"
    echo "                        Default: ${out_dir}"
    echo "    -v                 Enable verbose output"
    echo "    -t                 Build Student test ISO without examtool packages"
    echo "    -b                 Build ISO with non-signed systemd bootloader"
    echo "    -c                 Build with crypted root (&boot) partition(s)"
    echo "    -s                 Build a standalone ISO without CoW partition"
    echo "                        Default: disabled. This is deprecated."
    echo "    -h                 This help message"
    exit ${1}
}

# Helper function to run make_*() only one time per architecture.
run_once() {
    if [[ ! -e ${work_dir}/build.${1}_${arch} ]]; then
        $1
        touch ${work_dir}/build.${1}_${arch}
    fi
}

# Function to fix permissions of the files.
fix_permissions() {
    chown -R examosbuilder:users ../
    chown -R root:root airootfs/
    chown -R root:users efiboot/
    chown -R root:users SecureBoot_EFI_binaries/
    chown -R root:root Ubuntu_boot_files/
    chown -R root:users mkinitcpio.conf
    chown -R root:users packages.both
    chown -R root:users packages.release
    chown -R root:users pacman.conf
}

build_examos_utils() {
    echo "Building examOS utils package"
    local missing_files=""

    [[ ! -a "${DIR}/../tools/examos-utils/examos-utils/examos-shutdown/Makefile" ]] && { echo "WARN: Missing ../tools/examos-utils/examos-utils/examos-shutdown/Makefile"; missing_files="yes"; }
    
    if [ ! -z $missing_files ]; then
        echo "WARNING: Seems like some of the needed files for building examOS utility software are missing."
        echo "  Please use the konekoe delivery github repository to create the konekoe OS."
        echo "  If you are using the right repository, make sure that all the submodules are updated."
        echo "Exiting"
        exit 1
    fi

    sudo -u $SUDO_USER "${DIR}/../tools/examos-utils/build-examos-utils.sh"
}

build_examtool() {
    echo "Building examtool"
    local missing_files=""

    [[ ! -a "${DIR}/../tools/examtool/examtool/examtool-browser/Makefile" ]] && { echo "WARN: Missing ../tools/examtool/examtool/examtool-browser/Makefile"; missing_files="yes"; }
    [[ ! -a "${DIR}/../tools/examtool/examtool/examtool-osd/Makefile" ]] && { echo "WARN: Missing ../tools/examtool/examtool/examtool-osd/Makefile"; missing_files="yes"; }
    [[ ! -a "${DIR}/../tools/examtool/examtool/konekoe-electron-gui/Makefile" ]] && { echo "wARN: Missing ../tools/examtool/examtool/onekoe-electron-gui/Makefile"; missing_files="yes"; }
    [[ ! -a "${DIR}/../tools/examtool/examtool/examtool-service/Makefile" ]] && { echo "WARN: Missing ../tools/examtool/examtool/examtool-service/Makefile"; missing_files="yes"; }
    
    if [ ! -z $missing_files ]; then
        echo "WARNING: Seems like some of the needed files for building examtool software are missing."
        echo "  Please use the konekoe delivery github repository to create the konekoe OS."
        echo "  If you are using the right repository, make sure that all the submodules are updated."
        echo "Exiting"
        exit 1
    fi

    sudo -u $SUDO_USER "${DIR}/../tools/examtool/build-examtool.sh"
}

build_aur_packages() {
    echo "Packaging AUR packages"
    local missing_files=""

    [[ ! -a "${DIR}/../tools/examrepo/add-aur-packages.sh" ]] && { echo "WARN: Missing ../tools/examrepo/add-aur-packages.sh"; missing_files="yes"; }

    if [ ! -z $missing_files ]; then
        echo "WARNING: Seems like some of the needed files for packaking AUR packets are missing."
        echo "  Please use the konekoe delivery github repository to create the konekoe OS."
        echo "  If you are using the right repository, make sure that all the submodules are updated."

        prompt="Pick an option:"
        options=("Continue" "Quit")

        echo "Would you like to continue even though the examtool sources are missing?"
        PS3="$prompt "
        select opt in "${options[@]}"; do 

            case "$REPLY" in
            1 ) echo "Continuing";;
            2 ) echo "Exiting"; exit 1;;
            *) echo "Invalid option. Try another one.";continue;;
            esac

        done
    fi
    sudo -u $SUDO_USER "${DIR}/../tools/examrepo/add-aur-packages.sh"
}

# Setup custom pacman.conf with current cache directories.
make_pacman_conf() {
    local _cache_dirs
    _cache_dirs=($(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g'))
    sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n ${_cache_dirs[@]})|g" ${script_path}/pacman.conf > ${work_dir}/pacman.conf
}

# Base installation, plus needed packages (airootfs)
make_custom_airootfs() {
    local _airootfs="${work_dir}/${arch}/airootfs"
    mkdir -p -- "${_airootfs}"

    if [[ -d "${script_path}/airootfs" ]]; then
        cp -af --no-preserve=ownership -- "${script_path}/airootfs/." "${_airootfs}"

        # [[ -e "${_airootfs}/etc/shadow" ]] && chmod -f 0400 -- "${_airootfs}/etc/shadow"
        # [[ -e "${_airootfs}/etc/gshadow" ]] && chmod -f 0400 -- "${_airootfs}/etc/gshadow"
        # [[ -e "${_airootfs}/root" ]] && chmod -f 0750 -- "${_airootfs}/root"
    fi


    setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "base bash bzip2 coreutils file filesystem findutils gawk gcc-libs gettext glibc grep gzip iproute2 iputils licenses pacman pciutils procps-ng psmisc sed shadow systemd systemd-sysvcompat tar util-linux xz linux-lts linux" install
    setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "haveged intel-ucode amd-ucode memtest86+ mkinitcpio mkinitcpio-nfs-utils nbd" install
}

# Additional packages (airootfs)
make_packages() {
    if [ ! -z "$testbuild" ]; then
        echo "!!! INSTALLING TEST APPLICATIONS"
        setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "$(grep -h -v ^# ${script_path}/packages.both | sed ':a;N;$!ba;s/\n/ /g')" install
    else
        echo "!!! INSTALLING APPLICATIONS FOR RELEASE TOO"
        setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "$(grep -h -v ^# ${script_path}/packages.{both,release} | sed ':a;N;$!ba;s/\n/ /g')" install
    fi
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {

    # if we are building with disk encryption, we will need to create the crypt key here
    if [ ! -z "$crypted_partitions" ]; then
        dd bs=512 count=4 if=/dev/urandom of=${script_path}/crypto-keys/rootfs/${iso_name}-${iso_version}-x86_64${crypted_partitions}.iso.bin
        cp ${script_path}/crypto-keys/rootfs/${iso_name}-${iso_version}-x86_64${crypted_partitions}.iso.bin ${work_dir}/${arch}/airootfs/crypto_keyfile.bin
    fi

    # remove the old cowspace upperdir after the cowspace has been rw mounted
    # sed -i 's/mount -o remount,rw "\/run\/archiso\/cowspace"/mount -o remount,rw "\/run\/archiso\/cowspace"\n\t\trm -rf \/run\/archiso\/cowspace\/*/' ${work_dir}/${arch}/airootfs/etc/initcpio/hooks/archiso

    # old addition: grow cowspace. 
    #sed -i 's/cow_spacesize="256M"/cow_spacesize="2G"/' ${work_dir}/${arch}/airootfs/etc/initcpio/hooks/archiso
    #sed -i "s|/usr/lib/initcpio/|/etc/initcpio/|g" ${work_dir}/${arch}/airootfs/etc/initcpio/install/archiso_shutdown

    if [ ! -z "$crypted_partitions" ]; then
        cp ${script_path}/mkinitcpio-crypt.conf ${work_dir}/${arch}/airootfs/etc/mkinitcpio-archiso.conf
    else
        cp ${script_path}/mkinitcpio.conf ${work_dir}/${arch}/airootfs/etc/mkinitcpio-archiso.conf
    fi
    gnupg_fd=
    if [[ ${gpg_key} ]]; then
      gpg --export ${gpg_key} >${work_dir}/gpgkey
      exec 17<>${work_dir}/gpgkey
    fi

    # We create initramfs for both lts and fresh kernel variants
    ARCHISO_GNUPG_FD=${gpg_key:+17} setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r 'mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux-lts -g /boot/examos-lts.img' run
    if [[ ${gpg_key} ]]; then
      exec 17<&-
    fi

    ARCHISO_GNUPG_FD=${gpg_key:+17} setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r 'mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/examos.img' run
    if [[ ${gpg_key} ]]; then
      exec 17<&-
    fi
}

# Customize installation (airootfs)
make_customize_airootfs() {
    if [ ! -z "$testbuild" ]; then
        echo "!!! BUILDING TEST"
        setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r '/root/customize_airootfs_test.sh' run
    else
        echo "!!! BUILDING RELEASE"
        setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r '/root/customize_airootfs_release.sh' run
    fi

    setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r '/root/setup_wm.sh' run
    
    rm ${work_dir}/${arch}/airootfs/root/customize_airootfs_release.sh
    rm ${work_dir}/${arch}/airootfs/root/customize_airootfs_test.sh
    rm ${work_dir}/${arch}/airootfs/root/plank-dconf.ini
    rm ${work_dir}/${arch}/airootfs/root/setup_wm.sh
    if [ -f ${work_dir}/${arch}/airootfs/crypto_keyfile.bin ]; then
        rm ${work_dir}/${arch}/airootfs/crypto_keyfile.bin
    fi

    chmod -f 750 "${work_dir}/${arch}/airootfs/root"
}

# Prepare kernel and initramfs ${install_dir}/boot/
make_boot() {
    mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
    cp ${work_dir}/${arch}/airootfs/boot/examos-lts.img ${work_dir}/iso/${install_dir}/boot/${arch}/examos-lts.img
    cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux-lts ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz-linux-lts
    cp ${work_dir}/${arch}/airootfs/boot/examos.img ${work_dir}/iso/${install_dir}/boot/${arch}/examos.img
    cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz-linux
}

# Add other aditional/extra files to ${install_dir}/boot/
make_boot_extra() {
    if [[ -e "${work_dir}/x86_64/airootfs/boot/memtest86+/memtest.bin" ]]; then
        cp "${work_dir}/x86_64/airootfs/boot/memtest86+/memtest.bin" "${work_dir}/iso/${install_dir}/boot/memtest"
        mkdir -p "${work_dir}/iso/${install_dir}/boot/licenses/memtest86+/"
        cp "${work_dir}/x86_64/airootfs/usr/share/licenses/common/GPL2/license.txt" \
            "${work_dir}/iso/${install_dir}/boot/licenses/memtest86+/"
    fi
    if [[ -e "${work_dir}/x86_64/airootfs/boot/intel-ucode.img" ]]; then
        cp "${work_dir}/x86_64/airootfs/boot/intel-ucode.img" "${work_dir}/iso/${install_dir}/boot/"
        mkdir -p "${work_dir}/iso/${install_dir}/boot/licenses/intel-ucode/"
        cp "${work_dir}/x86_64/airootfs/usr/share/licenses/intel-ucode/"* \
            "${work_dir}/iso/${install_dir}/boot/licenses/intel-ucode/"
    fi
    if [[ -e "${work_dir}/x86_64/airootfs/boot/amd-ucode.img" ]]; then
        cp "${work_dir}/x86_64/airootfs/boot/amd-ucode.img" "${work_dir}/iso/${install_dir}/boot/"
        mkdir -p "${work_dir}/iso/${install_dir}/boot/licenses/amd-ucode/"
        cp "${work_dir}/x86_64/airootfs/usr/share/licenses/amd-ucode/"* \
            "${work_dir}/iso/${install_dir}/boot/licenses/amd-ucode/"
    fi
}


# Prepare certificate and sign bootloader/kernel
prepare_efi_signing() {
    # Sign binaries 
    echo "!!! PREPARING EFI SIGNING"
    # TODO: fix in future the file paths!
    sbsign --key ${script_path}/EFI_cert_keys/MOK.key --cert ${script_path}/EFI_cert_keys/MOK.crt --output ${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi
    sbsign --key ${script_path}/EFI_cert_keys/MOK.key --cert ${script_path}/EFI_cert_keys/MOK.crt --output ${work_dir}/iso/${install_dir}/boot/x86_64/vmlinuz ${work_dir}/iso/${install_dir}/boot/x86_64/vmlinuz
    # Copy MOK.cer to EFI partition, this is done in make_efiboot for El Torito!
    cp ${script_path}/EFI_cert_keys/MOK.cer ${work_dir}/iso/
    # cp ${script_path}/EFI_cert_keys/MOK.crt ${work_dir}/iso/
}

# Prepare /EFI
make_efi() {
    # if Ubuntu's GRUB
    if [ -z "$unsiged_bootloader" ]; then
        echo "!!! BUILDING WITH GRUB BOOTLOADER"
        mkdir -p ${work_dir}/iso/boot/grub
        cp -R ${script_path}/Ubuntu_boot_files/boot/grub ${work_dir}/iso/boot/

        mkdir -p ${work_dir}/iso/EFI/boot
        cp ${script_path}/Ubuntu_boot_files/EFI/BOOT/BOOTx64.EFI ${work_dir}/iso/EFI/boot/BOOTx64.EFI
        cp ${script_path}/Ubuntu_boot_files/EFI/BOOT/grubx64.efi ${work_dir}/iso/EFI/boot/grubx64.efi

        sed -i "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            ${work_dir}/iso/boot/grub/grub.cfg
    # else our own bootloader
    else
        echo "!!! BUILDING WITH CUSTOM BOOTLOADER"
        mkdir -p ${work_dir}/iso/EFI/boot
        # SecureBoot, obsolete code commented out
        cp ${script_path}/SecureBoot_EFI_binaries/shimx64.efi ${work_dir}/iso/EFI/boot/bootx64.efi
        cp ${script_path}/SecureBoot_EFI_binaries/mmx64.efi ${work_dir}/iso/EFI/boot/
        # cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/PreLoader.efi ${work_dir}/iso/EFI/boot/bootx64.efi
        # cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/HashTool.efi ${work_dir}/iso/EFI/boot/

        cp ${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/iso/EFI/boot/grubx64.efi

        mkdir -p ${work_dir}/iso/loader/entries
        cp ${script_path}/efiboot/loader/loader.conf ${work_dir}/iso/loader/
        # cp ${script_path}/efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/iso/loader/entries/
        # cp ${script_path}/efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/iso/loader/entries/

        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            ${script_path}/efiboot/loader/entries/examiso-x86_64-usb.conf > ${work_dir}/iso/loader/entries/examiso-x86_64.conf

        # EFI Shell 2.0 for UEFI 2.3+
        # curl -o ${work_dir}/iso/EFI/shellx64_v2.efi https://raw.githubusercontent.com/tianocore/edk2/master/ShellBinPkg/UefiShell/X64/Shell.efi
        # EFI Shell 1.0 for non UEFI 2.3+
        # curl -o ${work_dir}/iso/EFI/shellx64_v1.efi https://raw.githubusercontent.com/tianocore/edk2/master/EdkShellBinPkg/FullShell/X64/Shell_Full.efi
    fi
}

# Prepare efiboot.img::/EFI for "El Torito" EFI boot mode
# This is NOT used as from 20.12.2018!
make_efiboot() {
    mkdir -p ${work_dir}/iso/EFI/archiso
    truncate -s 64M ${work_dir}/iso/EFI/archiso/efiboot.img
    mkfs.fat -n ARCHISO_EFI ${work_dir}/iso/EFI/archiso/efiboot.img

    mkdir -p ${work_dir}/efiboot
    mount ${work_dir}/iso/EFI/archiso/efiboot.img ${work_dir}/efiboot

    mkdir -p ${work_dir}/efiboot/EFI/archiso
    cp ${work_dir}/iso/${install_dir}/boot/x86_64/vmlinuz-linux ${work_dir}/efiboot/EFI/archiso/vmlinuz-linux.efi
    cp ${work_dir}/iso/${install_dir}/boot/x86_64/examos.img ${work_dir}/efiboot/EFI/archiso/examos.img

    cp ${work_dir}/iso/${install_dir}/boot/intel_ucode.img ${work_dir}/efiboot/EFI/archiso/intel_ucode.img
    cp ${work_dir}/iso/${install_dir}/boot/amd_ucode.img ${work_dir}/efiboot/EFI/archiso/amd_ucode.img

    # if Ubuntu's GRUB
    if [ -z "$unsiged_bootloader" ]; then
        echo "!!! BUILDING WITH GRUB!"
        mkdir -p ${work_dir}/efiboot/EFI/boot

        cp ${script_path}/Ubuntu_boot_files/EFI/BOOT/BOOTx64.EFI ${work_dir}/efiboot/EFI/boot/BOOTx64.EFI
        cp ${script_path}/Ubuntu_boot_files/EFI/BOOT/grubx64.efi ${work_dir}/efiboot/EFI/boot/grubx64.efi

        mkdir -p ${work_dir}/efiboot/boot/grub
        cp -R ${script_path}/Ubuntu_boot_files/boot/grub ${work_dir}/efiboot/boot/

        sed -i "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            ${work_dir}/efiboot/boot/grub/grub.cfg
    # else our own bootloader
    else
        echo "!!! BUILDING WITH CUSTOM!"
        mkdir -p ${work_dir}/efiboot/EFI/boot
        # SecureBoot, obsolete code commented out
        cp ${script_path}/SecureBoot_EFI_binaries/shimx64.efi ${work_dir}/efiboot/EFI/boot/bootx64.efi
        cp ${script_path}/SecureBoot_EFI_binaries/mmx64.efi ${work_dir}/efiboot/EFI/boot/
        # cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/PreLoader.efi ${work_dir}/efiboot/EFI/boot/bootx64.efi
        # cp ${work_dir}/x86_64/airootfs/usr/share/efitools/efi/HashTool.efi ${work_dir}/efiboot/EFI/boot/

        cp ${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/efiboot/EFI/boot/grubx64.efi

        mkdir -p ${work_dir}/efiboot/loader/entries
        cp ${script_path}/efiboot/loader/loader.conf ${work_dir}/efiboot/loader/
        cp ${script_path}/efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/efiboot/loader/entries/
        cp ${script_path}/efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/efiboot/loader/entries/

        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            ${script_path}/efiboot/loader/entries/examiso-x86_64-cd.conf > ${work_dir}/efiboot/loader/entries/examiso-x86_64.conf

        cp ${work_dir}/iso/EFI/shellx64_v2.efi ${work_dir}/efiboot/EFI/
        cp ${work_dir}/iso/EFI/shellx64_v1.efi ${work_dir}/efiboot/EFI/
    fi

    umount -d ${work_dir}/efiboot
}

# Build airootfs filesystem image
make_prepare() {
    cp -a -l -f ${work_dir}/${arch}/airootfs ${work_dir}
    setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}" -D "${install_dir}" pkglist
    setarch ${arch} ${DIR}/mkexamiso ${verbose} -w "${work_dir}" -D "${install_dir}" -s sfs ${gpg_key:+-g ${gpg_key}} prepare
    rm -rf ${work_dir}/airootfs
    # rm -rf ${work_dir}/${arch}/airootfs (if low space, this helps)
}

# Build ISO
make_iso() {
    ${DIR}/mkexamiso ${verbose} -w "${work_dir}" -P "${examos_publisher}" -A "${examos_application}" -D "${install_dir}" -L "${iso_label}" -o "${out_dir}" iso "${iso_name}-${iso_version}-x86_64${crypted_partitions}${testbuild}.iso"
}

# This function creates the filesystem file skeleton.
#params: image_name, boot_size, efi_size, sfs_size, cow_size
create_filesystem_image() {
    local image_size=$(($2+$3+$4+$5+200))
    echo "Creating fs image with total size of ${image_size}"
    dd if=/dev/zero of="${1}" bs=1M count=${image_size}
    sync
    # create the partitions onto the virtual disk
    (
    echo o # Create a new empty GPT partition table
    echo Y # Yes
    echo n # new partition for BIOS boot
    echo 1 # number 1
    echo   # enter, use first possible sector
    echo "+${2}M" # 
    echo ef02 # type: BIOS boot
    echo n # new partition for 1st stage EFI
    echo 2 # number 2
    echo   # enter
    echo "+${3}M" #
    echo ef00 # type EFI
    echo n # partition for rootfs userland (airootfs.sfs)
    echo 3 # number 3
    echo     # enter
    echo "+${4}M" #
    echo 8300 # type Ext4
    echo n # last partition for CoW
    echo 4 # number 4
    echo   # enter
    echo "+${5}M" # 
    echo 8300 # type Ext4
    echo x # extra settings
    echo a # set attributes
    echo 1 # partition 1
    echo 2 # set legacy boot flag
    echo   # enter
    echo m # back to main menu opf gdisk
    echo w # WRITE
    echo Y # YES
    ) | gdisk "${1}" >/dev/null
    partprobe
}

make_image() {
    mkdir -p "${out_dir}"
    
    local rootfs_size="$(ls -s --block-size=1048576 "${work_dir}/iso/${install_dir}/x86_64/airootfs.sfs" | cut -d' ' -f1)"
    local rootfs_size=$(($rootfs_size+200))

    local image_name="${out_dir}/${iso_name}-${iso_version}-x86_64${crypted_partitions}${testbuild}.img"

    create_filesystem_image "${image_name}" 1 200 "${rootfs_size}" 1024

    sync

    local loop_name="/tmp/examos-builder-loop0"

    # TODO: check if the loop file is already there!
    mknod -m 0660 "/tmp/examos-builder-loop0" b 7 101
    # TODO: check if the loop mount should be removed!
    losetup -P "${loop_name}" "${image_name}"


    # drop the first line, as this is our LOOPDEV itself, but we only want the child partitions
    local loop_partitions=$(lsblk --raw --output "MAJ:MIN" --noheadings ${loop_name} | tail -n +2 | sort)
    local COUNTER=1
    for i in $loop_partitions; do
        MAJ=$(echo $i | cut -d: -f1)
        MIN=$(echo $i | cut -d: -f2)
        if [ ! -e "${loop_name}p${COUNTER}" ]; then mknod ${loop_name}p${COUNTER} b $MAJ $MIN; fi
        COUNTER=$((COUNTER + 1))
    done

    mkfs.fat -F32 "${loop_name}p2"
    mkfs.ext4 -F "${loop_name}p4"

    mkdir -p /mnt/image/{efi,root}

    mount "${loop_name}p2" /mnt/image/efi

    if [ ! -z "$crypted_partitions" ]; then
        echo YES | cryptsetup luksFormat --type luks2 "${loop_name}p3" -d "${script_path}/crypto-keys/rootfs/${iso_name}-${iso_version}-x86_64${crypted_partitions}.iso.bin"
        cryptsetup open "${loop_name}p3" cryptroot -d "${script_path}/crypto-keys/rootfs/${iso_name}-${iso_version}-x86_64${crypted_partitions}.iso.bin"
        mkfs.ext4 -F /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt/image/root
    else
        mkfs.ext4 -F "${loop_name}p3"
        mount "${loop_name}p3" /mnt/image/root
    fi

    # Copy EFI files
    cp -a -r "${work_dir}/iso/boot" /mnt/image/efi
    mkdir /mnt/image/efi/arch
    cp -a -r "${work_dir}/iso/arch/boot" /mnt/image/efi/arch
    cp -a -r "${work_dir}/iso/EFI" /mnt/image/efi

    #Copy rootfs
    mkdir /mnt/image/root/arch
    cp -a -r "${work_dir}/iso/arch/x86_64" /mnt/image/root/arch

    sync

    # create the bootloader entry
    local ARCHUUID=$(blkid -o value -s UUID "${loop_name}p3")
    local COWUUID=$(blkid -o value -s UUID "${loop_name}p4")

    if [ ! -z "$crypted_partitions" ]; then
        sed -i "s/archisolabel=.*/cryptdevice=UUID=$ARCHUUID:cryptroot root=\/dev\/mapper\/cryptroot archisodevice=\/dev\/mapper\/cryptroot cow_device=\/dev\/disk\/by-uuid\/$COWUUID cow_directory=\/persistent cow_persistent=P/" /mnt/image/efi/boot/grub/grub.cfg
    else
        sed -i "s/archisolabel=.*/archisodevice=\/dev\/disk\/by-uuid\/$ARCHUUID cow_device=\/dev\/disk\/by-uuid\/$COWUUID cow_directory=\/persistent cow_persistent=P/" /mnt/image/efi/boot/grub/grub.cfg
    fi

    # Install GRUB MBR
    grub-install --target=i386-pc --boot-directory=/mnt/image/efi/boot "${loop_name}"

    sync

    umount /mnt/image/efi
    umount /mnt/image/root

    if [ ! -z "$crypted_partitions" ]; then
        cryptsetup close cryptroot
    fi

    sleep 3
    sync

    losetup -d "${loop_name}"

    echo "Writing filesystem image completed."
}

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    _usage 1
fi

if [[ ${arch} != x86_64 ]]; then
    echo "This script needs to be run on x86_64"
    _usage 1
fi

while getopts 'N:V:L:D:w:o:g:vhtbcs' arg; do
    case "${arg}" in
        N) iso_name="${OPTARG}" ;;
        V) iso_version="${OPTARG}" ;;
        L) iso_label="${OPTARG}" ;;
        D) install_dir="${OPTARG}" ;;
        w) work_dir="${OPTARG}" ;;
        o) out_dir="${OPTARG}" ;;
        g) gpg_key="${OPTARG}" ;;
        v) verbose="-v" ;;
        t) testbuild="-test" ;;
        b) unsiged_bootloader="-b" ;;
        c) crypted_partitions="-crypto" ;;
        s) standalone="-s" ;;
        h) _usage 0 ;;
        *)
           echo "Invalid argument '${arg}'"
           _usage 1
           ;;
    esac
done

mkdir -p ${work_dir}

fix_permissions

run_once build_examos_utils

if [ -z "$testbuild" ]; then
    run_once build_examtool
fi

run_once build_aur_packages

run_once make_pacman_conf

# Do all stuff for each airootfs
for arch in x86_64; do
    run_once make_custom_airootfs
    run_once make_packages
done

for arch in x86_64; do
    run_once make_setup_mkinitcpio
    run_once make_customize_airootfs
done

for arch in x86_64; do
    run_once make_boot
done

# Do all stuff for "iso"
run_once make_boot_extra

# if we use our own bootloader,
if [ ! -z "$unsiged_bootloader" ]; then
    run_once prepare_efi_signing
fi
run_once make_efi
# run_once make_efiboot

for arch in x86_64; do
    run_once make_prepare
done

if [ ! -z "$standalone" ]; then
    run_once make_iso
else
    run_once make_image
fi

echo "Everything done, exiting."