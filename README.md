# simple_gcc_bash_builder
## Usage
```
./builder.sh (static|dynamic|exec|clean|strip|help)
```
## Brief
Compiles every source file from ./src directory recursively.
Then makes an executable or library file from compiled and other object(*.o) or archive(*.a) files from ./src into ./output directory.
Also exports every header file from ./src as soft link into ./include

## Options
<pre>
static      - Build static library
dynamic     - Build dynamic library
exec        - Build executable
clean       - Clean build results
strip       - Strip any executable or dynamic library from ./output
help        - Show help
</pre>

## Environment variables
<pre>
builder_FLAGS       - compiler flags (default: -O3 -Wall)
builder_LD_FLAGS    - linker flags   (default: )
builder_CC          - compiler       (default: g++)
builder_AR          - archiver       (default: ar)
builder_OUTPUT_NAME - the name of build result which can be an executable or library
                      ./output/<builder_OUTPUT_NAME> OR ./output/lib/lib<builder_OUTPUT_NAME>(.a|.so|.dll)
                      (default: output)
builder_NAMESPACE   - subdirectory name of exported include files
                      ./include/<builder_NAMESPACE>
                      (default: output)
</pre>
