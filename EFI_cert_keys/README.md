# Cert keys for MokManager/shim

If you want to use your own SecureBoot-enabled bootloader (shim needed!) with self-signing kernel and GRUB, generate keys here as in ArchWiki;

```
$ openssl req -newkey rsa:2048 -nodes -keyout MOK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Machine Owner Key/" -out MOK.crt
$ openssl x509 -outform DER -in MOK.crt -out MOK.cer
```

Signing itself is done in *build.sh*