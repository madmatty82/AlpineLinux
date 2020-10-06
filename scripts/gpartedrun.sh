mkpart boot ext4 1MiB 250MiB
print
set 1 boot on
print
mkpart swap linux-swap 250MiB 5%
print
mkpart vartmp ext4 5% 8%
print
mkpart home ext4 8% 13%
print
mkpart usr ext4 13% 35%
print
mkpart tmp ext4 35% 40%
print
mkpart varlogaudit ext4 40% 50%
print
mkpart varlog ext4 50% 60%
print
mkpart var ext4 60% 70%
print
mkpart / ext4 90% 99%
print
unit GiB
p