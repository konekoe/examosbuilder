# Crypting of both boot and root partitions

This method does not work on SecureBoot until own signed UEFI shim is used, as we need to generate our own grub binary for every unique USB stick

Theory of operation:

- There are 5 partitions on the disk,
	1. BIOS boot partition just after the MBR (1MiB)
	2. unencrypted, first-stage EFI partition which contains signed shim and generated GRUB that is able to decrypt the bootfs
	3. encrypted bootfs (ext4) including the GRUB config and kernel. The kernel is capable of enrypting the userland (rootfs)
	4. encrypted rootfs (ext4) including the squashfs image
	5. unencrypted CoW partition


## Creation and partitioning of disks (Theory of operation)
```
wipefs -af /dev/sda
gdisk /dev/sda
n					# new partition for BIOS boot
1					# number 1
					# enter, use first possible sector
+1M					# we use 1MiB
ef02				# type: BIOS boot
n 					# new partition for 1st stage EFI
2 					# number 2
					# enter
+10M 				# we use 10MiB
ef00 				# type EFI
n 					# new partition for bootfs (contains kernel etc)
3 					# partition number
					# enter
+100M				# we use 100MiB
8300 				# type Ext4
n 					# partition for rootfs userland (airootfs.sfs)
4 					# number 4
					# enter
+2G					# FIXME fix to correct size (airootfs.sfs + 50MiB)
8300 				# type Ext4
n 					# last partition for CoW
5 					# number 5
					# enter
					# enter	(use all space)
x 					# extra settings
a 					# set attributes
1 					# partition 1
2 					# set legacy boot flag
					# enter
m 					# back to main menu opf gdisk
w 					# WRITE
Y					# YES

sudo mkfs.fat -F32 /dev/sda2 		# format EFI

cryptsetup luksFormat /dev/sda3
YES		#it asks to do it? YES
*PASSUPASSU* (password123)				# type in the password here

cryptsetup luksFormat /dev/sda4
YES		#it asks to do it? YES
*PASSUPASSU* (password123)				# type in the password here

cryptsetup open /dev/sda3 cryptboot		# change "cryptboot" in future TO BE UNIQUE

mkfs.ext4 /dev/mapper/cryptboot

cryptsetup open /dev/sda4 cryptroot		# change "cryptroot" in future TO BE UNIQUE

mkfs.ext4 /dev/mapper/cryptroot

mkdir /mnt/boot				# change to UNIQUE
mount /dev/mapper/cryptboot /mnt/boot

mkdir /mnt/root				# change to UNIQUE
mount /dev/mapper/cryptroot /mnt/root

mkdir /mnt/efi				# change to UNIQUE
mount /dev/sda2 /mnt/efi

```

## Creation of the automatically-decrypting kernel

```
Done similarly in non-crypted boot partition, see its readme
```
