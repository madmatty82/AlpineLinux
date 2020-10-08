#mkpart primary ext 0% 100M   					#/boot			100MB 	/dev/sda1
#set 1 boot on
#mkpart primary swap linux-swap 100M 10%			#swap			100MB	/dev/sda2
#mkpart primary ext4 500M						#/				1024B	/dev/sda3
#mkpart extended 500M 100%						#
#mkpart logical 13% 20%							#/home 			1024MB	/dev/sda5
#mkpart logical									#/usr 			1024MB	/dev/sda6
#mkpart logical									#/tmp			250MB	/dev/sda7
#mkpart logical									#/var			750MB	/dev/sda8
#mkpart logical									#/var/log		750MB	/dev/sda9
#mkpart logical									#/var/log/audit	750MB	/dev/sda10
#mkpart logical									#/var/tmp		500MB	/dev/sda11	
												#/opt			15MB	/dev/sda12	
									
								
mkdir -p /mnt/boot /mnt/home /mnt/usr /mnt/tmp /mnt/var /mnt/var/log /mnt/var/log/audit /mnt/var/tmp /mnt/opt
mount /dev/sda3 /mnt
mount /dev/sda5 /mnt/home
mount /dev/sda6 /mnt/usr
mount /dev/sda7 /mnt/tmp
mount /dev/sda8 /mnt/var
mount /dev/sda9 /mnt/var/log
mount /dev/sda10 /mnt/var/log/audit
mount /dev/sda11 /mnt/var/tmp
mount /dev/sda12 /mnt/opt

mount
							