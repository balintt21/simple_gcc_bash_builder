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
    builder_LD_FLAGS=ld
fi

NAMESPACE="ivs_protocol"
OUTPUT_NAME="ivsprotocol"

gather_includes()
{
    if [ ! -d "include" ]; then
        mkdir -p "include/$NAMESPACE"
    else
        rm -r "include/$NAMESPACE"
    fi

    include_files="$(find $(pwd)/src -type f,l -iregex '.*\.\(h\|inl\)' -printf 'src/%P ')"

    IFS=' ' read -r -a includes <<< "$include_files"
    for element in "${includes[@]}"
    do
        include_abs_path="$(pwd)/$element"
        include_rel_path="$(echo $element | cut -d'/' -f2- )"
        include_dir="$(pwd)/include/$NAMESPACE/$(dirname $include_rel_path)"
        if [ ! -d "$include_dir" ]; then
            mkdir -p $include_dir
        fi
        cp -sr "$include_abs_path" "include/$NAMESPACE/$include_rel_path"
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
    source_files="$(find $(pwd)/src -type f,l -iregex '.*\.cpp' -printf 'src/%P ')"

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

    for element in "${sources[@]}"
    do
        source_file=$(echo "$element" | cut -d'.' -f1)
        source_file_name=${source_file##*/}
        source_file_checksum=$($builder_CC $builder_FLAGS  -E $source_file.cpp -o - | md5sum  | cut -d' ' -f1)
        prev_checksum_of_source_file=""

        if [ -f "build/$source_file_name.md5" ]; then
            prev_checksum_of_source_file=$(cat build/"$source_file_name".md5)
        fi

        if [ "$source_file_checksum" != "$prev_checksum_of_source_file" ] || [ "$build_type" != "$prev_build_type" ]; then
            echo "    $source_file.cpp -> $source_file_name.o"
            $builder_CC $builder_FLAGS -c "$source_file.cpp" -o "build/$source_file_name.o"

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

if [ -z $1 ] || [ "$1" == "help" ]; then
    echo "Usage: $0 (static|dynamic|exec|clean|help)"
    echo "Options"
    echo "    static  - Build static library"
    echo "    dynamic - Build dynamic library"
    echo "    exec    - Build executable"
    echo "    clean   - Clean build results"
    echo "    help    - Show this help"
    echo "Environment variables"
    echo "    builder_FLAGS    - compiler flags"
    echo "    builder_LD_FLAGS - linker flags"
    echo "    builder_CC       - compiler"
    echo "    builder_AR       - archiver"
elif [ "$1" == "dynamic" ]; then
    echo "Dynamic build."

    gather_includes
    build $1

    if [ "$number_of_changes" != "0" ]; then
        if [ ! -d "output" ]; then
          mkdir -p output/lib
        fi
        
	    gather_object_files

	    echo "Linking with $builder_CC."
        echo $object_files
	    $builder_CC -shared -o "output/lib/lib$OUTPUT_NAME.so" $object_files
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
        if [ ! -d "output" ]; then
          mkdir -p output/lib
        fi

        gather_object_files
        
        echo "Linking static library"
        $builder_AR rvs "output/lib/lib$OUTPUT_NAME.a" $object_files
        echo "Output: output/lib/lib$OUTPUT_NAME.a"
        echo "Done."
    else
        echo "Nothing has changed since the last build."
    fi
elif [ "$1" == "exec" ]; then
    echo "Building executable."
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
fi

exit 0

