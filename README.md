# simple_gcc_bash_builder
## Usage
```
./builder.sh (static|dynamic|exec|clean|strip|help) [OUTPUT_NAME] [NAMESPACE]
```
_\(Everything between [] is optional.\)_

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
strip       - Strip any executable or dynamic library from ./output (see strip --help)
help        - Show help
</pre>

## Environment variables
<pre>
builder_CROSS_COMPILE - cross compiler path/prefix
builder_CC            - C compiler         (default: gcc)
builder_CXX           - C++ compiler       (default: g++)
builder_AS            - Assembler          (default: as)
builder_AR            - archiver           (default: ar)
builder_CC_FLAGS      - C compiler flags   (default: -O3 -Wall)
builder_CXX_FLAGS     - C++ compiler flags (default: -O3 -Wall)
builder_AS_FLAGS      - Assembler flags
builder_LD_FLAGS      - linker flags       (default: )
builder_OUTPUT_NAME - the name of build result which can be an executable or library
                      ./output/<builder_OUTPUT_NAME> OR ./output/lib/lib<builder_OUTPUT_NAME>(.a|.so|.dll)
                      (default: output)
builder_NAMESPACE   - subdirectory name of exported include files
                      ./include/<builder_NAMESPACE>
                      (default: output)
</pre>

## Directory structure
<pre>
build   - Object files and other artifacts
include - Exported includes from ./src : <b>*.(h|hh|H|hp|hxx|hpp|HPP|h++|tcc|inl)</b>
output  - Build results
src     - Source files : <b>*.(c|i|ii|cc|cp|cxx|cpp|CPP|c++|C|s|S|sx)</b>
</pre>

## Excluding source files
To exclude source files a ./src/.exclude or ./src/.<build_type>.exclude file must exists.<br/>
If ./src/.exclude exists then it overrides every build type specific exclude file.<br/>
An exclude file should contain lines of relative pathes of files to exclude from ./src directory.
### Example:
<pre>
touch ./src/.exclude
ls -R ./src
./src:
main.cpp  test

./src/test:
test.cpp  test.hpp
echo "test/test.cpp" >> ./src/.exclude
</pre>
