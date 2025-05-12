flash `u-boot` to `rockchip` devices:  

```bash
sudo dd if=u-boot-rockchip.bin of=/dev/DEVICE seek=64 && sync
```
