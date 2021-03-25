# Crypting of only root partition

## CAUTION: THIS IS DANGEROUS AND NOT REALLY SECURE: THE KERNEL IS ON AN UNENCRYPTED PARTITION ON THE USB

Theory of operation:

- There are 4 partitions on the disk,
	1. BIOS boot partition just after the MBR (1MiB)
	2. unencrypted, EFI partition which contains shim, GRUB and the kernel
	3. encrypted rootfs (ext4) including the squashfs image
	4. unencrypted CoW partition


## Creation and partitioning of disks
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
+100M 				# we use 100MiB
ef00 				# type EFI
n 					# partition for rootfs userland (airootfs.sfs)
3 					# number 3
					# enter
+2G					# FIXME fix to correct size (airootfs.sfs + 50MiB) <-- fixed in script
8300 				# type Ext4
n 					# last partition for CoW
4 					# number 4
					# enter
					# enter	(use all space)
8300 				# type Ext4
x 					# extra settings
a 					# set attributes
1 					# partition 1
2 					# set legacy boot flag
					# enter
m 					# back to main menu opf gdisk
w 					# WRITE
Y					# YES

sudo mkfs.fat -F32 /dev/sda2 		# format EFI

cryptsetup luksFormat --type luks2 /dev/sda3
YES									#it asks to do it? YES
*PASSUPASSU* (passu123)				# type in the password here
sudo cryptsetup luksAddKey /dev/sda3 work/x86_64/airootfs/crypto_keyfile.bin
sudo cryptsetup luksRemoveKey /dev/sda3		# remove the first-given crypt key

cryptsetup open /dev/sda3 cryptroot	-d work/x86_64/airootfs/crypto_keyfile.bin

mkfs.ext4 /dev/mapper/cryptroot

mkdir /mnt/root				# change to UNIQUE
mount /dev/mapper/cryptroot /mnt/root

mkdir /mnt/efi				# change to UNIQUE
mount /dev/sda2 /mnt/efi

```

## Creation of the automatically-decrypting kernel

```
See build-script and mkinitcpio-crypt.conf, it's that easy! (Hint, early userspace has the keyfile stored in /crypto_keyfile.bin)
```
