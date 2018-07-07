#!/bin/bash

if [ -z "$builder_FLAGS" ]; then
    builder_FLAGS="-O3 -Wall"
fi
if [ -z "$builder_CC" ]; then
    builder_CC=g++
fi
if [ -z "$builder_AR" ]; then
    builder_AR=ar
fi
if [ -z "$builder_LD_FLAGS" ]; then
    builder_LD_FLAGS=""
fi
if [ -z "$builder_OUTPUT_NAME" ]; then
    builder_OUTPUT_NAME="output"
fi
if [ ! -z "$2" ]; then
    builder_OUTPUT_NAME="$2"
fi
if [ -z "$builder_NAMESPACE" ]; then
    builder_NAMESPACE="$builder_OUTPUT_NAME"
fi
if [ ! -z "$3" ]; then
    builder_NAMESPACE="$3"
fi

gather_includes()
{
    if [ ! -d "include" ]; then
        mkdir -p "include/$builder_NAMESPACE"
    else
        rm -r "include/$builder_NAMESPACE"
    fi

    include_files="$(find $(pwd)/src -type f,l -iregex '.*\.\(h\|hh\|H\|hp\|hxx\|hpp\|HPP\|h++\|tcc\|inl\)' -printf 'src/%P ')"

    IFS=' ' read -r -a includes <<< "$include_files"
    for element in "${includes[@]}"
    do
        include_abs_path="$(pwd)/$element"
        include_rel_path="$(echo $element | cut -d'/' -f2- )"
        include_dir="$(pwd)/include/$builder_NAMESPACE/$(dirname $include_rel_path)"
        if [ ! -d "$include_dir" ]; then
            mkdir -p $include_dir
        fi
        cp -sr "$include_abs_path" "include/$builder_NAMESPACE/$include_rel_path"
    done
}

build()
{
    if [ ! -d "build" ]; then
      mkdir build
    fi

    build_type="static"
    prev_build_type=""
    number_of_changes=0
    source_files="$(find $(pwd)/src -type f,l -iregex '.*\.\(c\|i\|ii\|cc\|cp\|cxx\|cpp\|CPP\|c++\|C\|s\|S\|sx\)' -printf 'src/%P ')"

    if [ "$1" == "dynamic" ]; then
        build_type="$1"
        builder_FLAGS="$builder_FLAGS -fPIC"
    fi

    if [ -f "build/build.type" ]; then
        prev_build_type=$(cat build/build.type)
    fi

    echo -n "$build_type" > build/build.type

    IFS=' ' read -r -a sources <<< "$source_files"
    echo "Compiling with: $builder_CC $builder_FLAGS"

    for source_file in "${sources[@]}"
    do
        source_file_name=$(echo "$source_file" | cut -d'.' -f1)
        source_file_name=${source_file##*/}
        source_file_checksum=$($builder_CC $builder_FLAGS  -E $source_file -o - | md5sum  | cut -d' ' -f1)
        prev_checksum_of_source_file=""

        if [ -f "build/$source_file_name.md5" ]; then
            prev_checksum_of_source_file=$(cat build/"$source_file_name".md5)
        fi

        if [ "$source_file_checksum" != "$prev_checksum_of_source_file" ] || [ "$build_type" != "$prev_build_type" ]; then
            echo "    $source_file -> $source_file_name.o"
            $builder_CC $builder_FLAGS -c "$source_file" -o "build/$source_file_name.o"

            if [ $? -ne 0 ]; then
                echo "Build failed!"
                exit 1
            fi

            number_of_changes=$((number_of_changes+1))
            echo -n "$source_file_checksum" > "build/$source_file_name.md5"
        fi
    done
}

gather_object_files()
{
    object_files="$(find $(pwd)/build -type f,l -iregex '.*\.\(o\|a\)' -printf 'build/%P ')"
    object_files="$object_files$(find $(pwd)/src -type f,l -iregex '.*\.\(o\|a\)' -printf 'src/%P ')"
}

if [ ! -d "src" ]; then
    mkdir src
fi

if [ -z $1 ] || [ "$1" == "help" ]; then
    echo -e "Usage: $0 (static|dynamic|exec|clean|strip|help) [output_name] [namespace]\n\t(Everything between [] is optional.)\n"\
"Brief\n"\
"\tCompiles every source file from ./src directory then makes an executable or library file \n\tfrom compiled and other object(*.o) or archive(*.a) files from ./src into ./output.\n"\
"\tAlso exports every header file from ./src as soft link into ./include\n\n\t(recursive)\n"\
"Options\n"\
"\tstatic\t\t\t- Build static library\n"\
"\tdynamic\t\t\t- Build dynamic library\n"\
"\texec\t\t\t- Build executable\n"\
"\tclean\t\t\t- Clean build results\n"\
"\tstrip\t\t\t- Strips any executable or dynamic library from ./output\n"\
"\thelp\t\t\t- Show this help\n"\
"Environment variables\n"\
"\tbuilder_FLAGS\t\t- compiler flags (default: -O3 -Wall)\n"\
"\tbuilder_LD_FLAGS\t- linker flags   (default: )\n"\
"\tbuilder_CC\t\t- compiler       (default: g++)\n"\
"\tbuilder_AR\t\t- archiver       (default: ar)\n"\
"\tbuilder_OUTPUT_NAME\t- the name of build result which can be an executable or library\n"\
"\t\t\t\t  ./output/<builder_OUTPUT_NAME> OR ./output/lib/lib<builder_OUTPUT_NAME>(.a|.so|.dll)\n"\
"\t\t\t\t  (default: output)\n"\
"\tbuilder_NAMESPACE\t- subdirectory name of exported include files\n"\
"\t\t\t\t  ./include/<builder_NAMESPACE>\n"\
"\t\t\t\t  (default: output)\n"\
"Directory structure\n"\
"\tbuild\t\t\t- Object files and other artifacts\n"\
"\tinclude\t\t\t- Exported includes from ./src : *.(h|hh|H|hp|hxx|hpp|HPP|h++|tcc|inl)\n"\
"\toutput\t\t\t- Build results\n"\
"\tsrc\t\t\t- Source files : *.(c|i|ii|cc|cp|cxx|cpp|CPP|c++|C|s|S|sx)"

elif [ "$1" == "dynamic" ]; then
    echo "Dynamic build."

    gather_includes
    build $1

    echo -n "dynamic" > build/build.type

    if [ "$number_of_changes" != "0" ]; then
        if [ ! -d "output/lib" ]; then
          mkdir -p output/lib
        fi
        
	    gather_object_files

	    echo "Linking with $builder_CC."
        echo $object_files
	    $builder_CC -shared $builder_LD_FLAGS -o "output/lib/lib$builder_OUTPUT_NAME.so" $object_files
	    if [ $? -ne 0 ]; then
	        echo "Build failed!"
	        exit 1
	    fi
	    echo "Done."
	else
		echo "Nothing has changed since the last build."
	fi
elif [ "$1" == "static" ]; then
    echo "Static build."
    
    gather_includes
    build

    echo -n "static" > build/build.type

    if [ "$number_of_changes" != "0" ]; then
        if [ ! -d "output/lib" ]; then
          mkdir -p output/lib
        fi

        gather_object_files
        
        echo "Linking static library"
        $builder_AR rvs "output/lib/lib$builder_OUTPUT_NAME.a" $object_files
        echo "Output: output/lib/lib$builder_OUTPUT_NAME.a"
        echo "Done."
    else
        echo "Nothing has changed since the last build."
    fi
elif [ "$1" == "exec" ]; then
    echo "Building executable."

    gather_includes
    build $1

    echo -n "executable" > build/build.type

    if [ "$number_of_changes" != "0" ]; then
        if [ ! -d "output" ]; then
          mkdir -p output
        fi
        
	    gather_object_files

	    echo "Linking with $builder_CC."
        echo $object_files
	    $builder_CC $builder_LD_FLAGS -o "output/$builder_OUTPUT_NAME" $object_files
	    if [ $? -ne 0 ]; then
	        echo "Build failed!"
	        exit 1
	    fi
	    echo "Done."
	else
		echo "Nothing has changed since the last build."
	fi
elif [ "$1" == "clean" ]; then
    echo "rm -r build/"
    if [ -d "build" ]; then
      rm -r build
    fi
    echo "rm -r output/"
    if [ -d "output" ]; then
        rm -r output
    fi
    echo "rm -r include/"
    if [ -d "include" ]; then
        rm -r include
    fi
elif [ "$1" == "strip" ]; then
    #TODO use find
    to_strip="output/$builder_OUTPUT_NAME"
    if [ -f "$to_strip" ]; then
        echo "strip --strip-unneeded $to_strip"
        strip --strip-unneeded "$to_strip"
    fi
    to_strip="output/lib/lib$builder_OUTPUT_NAME.so"
    if [ -f "$to_strip" ]; then
        echo "strip --strip-unneeded $to_strip"
        strip --strip-unneeded "$to_strip"
    fi
    to_strip="output/lib/lib$builder_OUTPUT_NAME.dll"
    if [ -f "$to_strip" ]; then
        echo "strip --strip-unneeded $to_strip"
        strip --strip-unneeded "$to_strip"
    fi
else
    echo "Unrecognized parameter: \"$1\"!"
fi

exit 0

