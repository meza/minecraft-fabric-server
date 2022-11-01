docker run --rm -it \
--name "mct" \
-e LOCAL_UID="$(id -u "$USER")" \
-e LOCAL_GID="$(id -g "$USER")" \
-v"$(pwd)/tmp/backups:/minecraft/backups" \
-v"$(pwd)/tmp/world:/minecraft/world" \
-v"$(pwd)/tmp/config:/minecraft/config" \
mctest
