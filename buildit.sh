#!/bin/bash

echo "Deleting a.img..."

rm a.img

echo "Creating a.img..."

bximage -q -mode=create -fd=1.44M a.img

if [ "$#" -ne 1 ]; then
	echo "Building Docker image..."
	docker build -t brokenthorn .
	export CONTAINER_ID=`docker ps -alq`
else
	export CONTAINER_ID=$1
	echo "Using container $CONTAINER_ID"
fi

echo "Assembling..."

docker run -it brokenthorn
docker cp `docker ps -alq`:/app/boot1.bin .
docker cp `docker ps -alq`:/app/KRNLDR.SYS .
docker cp `docker ps -alq`:/app/KRNL.SYS .

if [ -f "a.img" ]; then
	echo "Copying bootloader to boot sector of a.img..."
	dd if=boot1.bin of=a.img bs=512 conv=notrunc
else
	echo "Floppy disk image a.img doesn't exist."
fi
echo "Copying files to a.img..."

export MOUNT_OUT=`hdiutil attach a.img`
export DISK_NAME=`echo $MOUNT_OUT | awk -F' /' '{print $1}'`
export MOUNT_DIR=`echo $MOUNT_OUT | awk -F' /' '{print "/" $2}'`

cp KRNLDR.SYS "$MOUNT_DIR"
cp KRNL.SYS "$MOUNT_DIR"
hdiutil detach "$DISK_NAME"

echo "Done."
