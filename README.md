### What

A primitive set of scripts to build an abstract Rust program for different OSs. Currently supports Linux (both host- and container-wise) and Freebsd. And can be easily extended to build on other platforms.

### Why

There may be cases when you create a Rust program to ultimately run it on a machine different from your development one, and this program won't start there because that system is too old. 

Quite often this will be represented by the following error:
```
$ ./myprog 
./myprog: /lib64/libc.so.6: version `GLIBC_2.28' not found (required by ./myprog)
```

### How

#### Preparation: to be done once, in the beginning

1. Add this repo as a submobule your of Rust project.

2. Copy `PLATFORMS.example` to `PLATFORMS` and describe platforms that you need. Example values are self-explanatory.

3. Copy `INSTALL_SPEC.example` to `INSTALL_SPEC` and list files and directories that are required to build your project.

4. Prepare a building environment, for example: `./build.sh my_program_name --image centos7`,
where the `my_program_name` is an arbitrary name to identify containers during the building stage.

#### Building: to be done when you need to produce the binary

Example: `./build.sh my_program_name --app centos7`
