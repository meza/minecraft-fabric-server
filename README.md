# BASE IMAGE

Sourcecode: https://github.com/meza/minecraft-fabric-server

> This is not meant to be used as a standalone image, and it's heavily under development.

## Configuration for runtime

### Volumes

#### /minecraft/setup-files

This will be the home for the configuration files your server uses.

The **server** folder contains the actual server configuration files.

This is where the server.properties file and the rest is located.

The files in this folder will be symlinked into the minecraft server's server folder.
The server.properties file will be copied over to the server folder and the contents will be adjusted
to match the configuration you set.

The configuration that gets set is as follows:
- server-port
- query.port
- rcon.port
- rcon.password

The **datapacks** folder contains the datapacks for the server.
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

The amount of memory allocated to the young generation. This is a Java argument. 
Defaults to 1g (25% of the 4GB heap) which is optimized for Minecraft server performance.

### MAX_THREADS

The maximum number of threads the server can use. This is a Java argument.

### Performance Tuning Parameters

The following environment variables allow you to tune JVM performance based on your server's hardware:

#### G1_HEAP_REGION_SIZE

Controls the size of G1 heap regions. Defaults to `32M` which is optimized for 4GB+ heaps. 
For smaller heaps (1-2GB), consider `16M` or `8M`.

#### PARALLEL_GC_THREADS

Number of parallel garbage collection threads. Defaults to `8` (optimized for 8-core CPUs).
Set this to match your CPU core count for optimal performance.

#### CONCURRENT_GC_THREADS

Number of concurrent garbage collection threads. Defaults to `2` (typically 1/4 of parallel threads).
Recommended: PARALLEL_GC_THREADS / 4.

#### USE_STRING_DEDUPLICATION

Enable string deduplication to reduce memory usage. Defaults to `true`.
Set to `false` to disable if you experience issues.

#### OPTIMIZE_STRING_CONCAT

Enable optimized string concatenation. Defaults to `true`.
Set to `false` to disable if you experience compatibility issues.

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
