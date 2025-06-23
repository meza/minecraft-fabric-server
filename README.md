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

The following environment variables allow fine-tuning of JVM performance based on your server's hardware. 
These parameters implement Aikar's flags with hardware-specific optimizations:

#### Memory Configuration

##### G1_HEAP_REGION_SIZE
Controls the size of G1 heap regions. Larger regions reduce management overhead but require more memory.

- **Default**: `32M` (optimized for 4GB+ heaps)
- **Recommended**: 
  - `8M` for heaps < 2GB
  - `16M` for heaps 2-4GB  
  - `32M` for heaps > 4GB
- **Example**: `G1_HEAP_REGION_SIZE=16M`

#### CPU Configuration

##### PARALLEL_GC_THREADS
Number of parallel garbage collection threads for stop-the-world collections.

- **Default**: `8` (optimized for 8-core CPUs like i7-7700K)
- **Recommended**: Set to your CPU core count
- **Range**: 1-16 (higher values may cause overhead)
- **Example**: `PARALLEL_GC_THREADS=4` for quad-core CPU

##### CONCURRENT_GC_THREADS  
Number of concurrent garbage collection threads that run alongside your application.

- **Default**: `2` (optimized for 8-core systems)
- **Recommended**: PARALLEL_GC_THREADS ÷ 4
- **Range**: 1-8 (should be much smaller than parallel threads)
- **Example**: `CONCURRENT_GC_THREADS=1` for quad-core CPU

#### Optimization Features

##### USE_STRING_DEDUPLICATION
Enables G1's string deduplication feature to reduce memory usage by sharing identical string data.

- **Default**: `true`
- **Benefits**: Reduces heap usage, especially beneficial for Minecraft's many duplicate strings
- **Overhead**: Minimal CPU cost for significant memory savings
- **Example**: `USE_STRING_DEDUPLICATION=false` to disable

##### OPTIMIZE_STRING_CONCAT
Enables optimized string concatenation for better performance.

- **Default**: `true`  
- **Benefits**: Faster string operations, reduces temporary object creation
- **Compatibility**: Generally safe, disable only if compatibility issues arise
- **Example**: `OPTIMIZE_STRING_CONCAT=false` to disable

#### Configuration Examples

**High-performance 8-core server (32GB RAM):**
```bash
XMX=8g
XMN=2g  
G1_HEAP_REGION_SIZE=32M
PARALLEL_GC_THREADS=8
CONCURRENT_GC_THREADS=2
```

**Budget 4-core server (16GB RAM):**
```bash
XMX=4g
XMN=1g
G1_HEAP_REGION_SIZE=16M  
PARALLEL_GC_THREADS=4
CONCURRENT_GC_THREADS=1
```

**Low-resource 2-core server (8GB RAM):**
```bash
XMX=2g
XMN=512m
G1_HEAP_REGION_SIZE=8M
PARALLEL_GC_THREADS=2
CONCURRENT_GC_THREADS=1
```

### Backup Schedule

The image no longer hard codes when backups run. Instead you can control the cron
schedule with environment variables:

- `CRON_PURGE` &ndash; purge old backups (default `15 08 */7 * *`)
- `CRON_BACKUP` &ndash; run incremental backups (default `0 * * * *`)
- `CRON_FULL` &ndash; create a full backup (default `30 05 * * *`)

Set any of these variables to an empty value to disable the corresponding task.

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

## Troubleshooting

### Performance Issues

If you're experiencing poor performance, check the following:

1. **Memory Configuration**: Ensure XMN is approximately 25% of XMX
2. **GC Thread Counts**: Match PARALLEL_GC_THREADS to your CPU core count
3. **Heap Region Size**: Use larger regions (32M) for heaps > 4GB
4. **Validation Warnings**: Check server logs for configuration warnings

### Configuration Validation

The server performs automatic validation of JVM parameters on startup:
- Memory values must end with 'm' or 'g' (e.g., `XMX=4g`)
- Thread counts must be positive integers
- Heap region sizes must end with 'm' or 'k' (e.g., `G1_HEAP_REGION_SIZE=32m`)

### Common Issues

- **High GC overhead**: Reduce PARALLEL_GC_THREADS if > CPU cores
- **Memory errors**: Ensure XMN < XMX and both are appropriate for available RAM
- **Startup failures**: Check that all environment variables have valid formats
