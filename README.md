# BASE IMAGE

Sourcecode: https://github.com/meza/minecraft-fabric-server

> This is not meant to be used as a standalone image, and it's heavily under development.

## Configuration for runtime

### Volumes

#### /minecraft/setup-files

This will be the home for the configuration files your server uses.

The **server** folder contains the actual server configuration files.

This is where the server.properties file is located.

The files in this folder will be copied over to the minecraft server's server folder.
The following file extensions will be copied over to the server
- json
- properties
- conf
- png
- lock
- yml
- db
- txt

Everything else will be ignored.

The server.properties file will be copied over to the server folder and the contents will be adjusted
to match the configuration you set.

The configuration that gets set is as follows:
- server-port
- query.port
- rcon.port
- rcon.password

The **server/config** folder contains the configuration files for the mods.
Everything in this folder will be used.

The **server/datapacks** folder contains the datapacks for the server.
Everything in this folder will be used and will override the world/datapacks folder.

The **scripts/configure.sh** script will be run after the server has been configured.
This is where you can add your own configuration.


TBD:

- configure.sh

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

### /minecraft/setup-files

Contains the configuration files.

This has a few subfolders

#### /minecraft/setup-files/server

This contains the vanilla server configuration files.

#### /minecraft/setup-files/server/config

This contains the configuration files for the mods.


### /minecraft/backups

Contains the backups of the server.
