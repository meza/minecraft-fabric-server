# BASE IMAGE

Sourcecode: https://github.com/meza/minecraft-fabric-server

> This is not meant to be used as a standalone image, and it's heavily under development.

## Build Arguments

### MINECRAFT VERSION

You can supply the minecraft version you want as follows

`docker build --build-arg MINECRAFT_VERSION=1.18.2 .`

### RCON_PORT

You can supply the port you want to use for RCON as follows

`docker build --build-arg RCON_PORT=25575 .`

### RCON_PASSWORD

You can supply the password you want to use for RCON as follows

`docker build --build-arg RCON_PASSWORD=minecraft .`

### MINECRAFT_PORT

You can supply the port you want to use for the minecraft server as follows

`docker build --build-arg MINECRAFT_PORT=25565 .`

### QUERY_PORT

You can supply the port you want to use for the minecraft server query as follows

`docker build --build-arg QUERY_PORT=25565 .`

## Environment Variables

### NAME

The default name of the server is `minecraft`

### XMS

The minimum amount of memory the server can use. This is a Java argument.

### XMX

The maximum amount of memory the server can use. This is a Java argument.

### XMN

The minimum amount of memory the server can use for the young generation. This is a Java argument.

### MAX_THREADS

The maximum number of threads the server can use. This is a Java argument.

### AUTO_UPDATE

If set to `true`, the server will automatically update the mods when booting up.

Requires the [Minecraft Mod Manager](https://github.com/meza/minecraft-mod-manager)'s `modlist.json` to be present in the `/minecraft/config/server` directory.

## Volumes

The image defines the following volumes:

### /minecraft/world

Contains the world data. This is where the save files are stored.

### /minecraft/config

Contains the configuration files.

This has a few subfolders

#### /minecraft/config/server

This contains the vanilla server configuration files.

#### /minecraft/config/config

This contains the configuration files for the mods.


### /minecraft/backups

Contains the backups of the server.
