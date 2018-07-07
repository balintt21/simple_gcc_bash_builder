# simple_gcc_bash_builder
## Usage
```
./builder.sh (static|dynamic|exec|clean|strip|help)
```
## Brief
Compiles every source file from ./src directory recursively.
Then makes an executable or library file from compiled and other object(*.o) or archive(*.a) files from ./src into ./output directory.
Also exports every header file from ./src as soft link into ./include
