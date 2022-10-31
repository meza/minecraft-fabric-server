docker run --rm -it \
--name "mct" \
-v"$(pwd)/tmp/backups:/minecraft/backups" \
-v"$(pwd)/tmp/world:/minecraft/world" \
-v"$(pwd)/tmp/config:/minecraft/config" \
mctest bash
