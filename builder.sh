#!/bin/bash

if [ -z "$builder_CROSS_COMPILE" ]; then
    builder_CROSS_COMPILE=""
fi
if [ -z "$builder_CC_FLAGS" ]; then
    builder_CC_FLAGS="-O3 -Wall"
fi
if [ -z "$builder_CXX_FLAGS" ]; then
    builder_CXX_FLAGS="-O3 -Wall"
fi
if [ -z "$builder_AS_FLAGS" ]; then
    builder_AS_FLAGS=""
fi
if [ -z "$builder_CC" ]; then
    builder_CC="${builder_CROSS_COMPILE}gcc"
fi
if [ -z "$builder_CXX" ]; then
    builder_CXX="${builder_CROSS_COMPILE}g++"
fi
if [ -z "$builder_AS" ]; then
    builder_AS="${builder_CROSS_COMPILE}as"
fi
if [ -z "$builder_AR" ]; then
    builder_AR="${builder_CROSS_COMPILE}ar"
fi
if [ -z "$builder_LD_FLAGS" ]; then
    builder_LD_FLAGS=""
fi
if [ -z "$builder_OUTPUT_NAME" ]; then
    builder_OUTPUT_NAME="output"
fi
if [ -n "$2" ]; then
    builder_OUTPUT_NAME="$2"
fi
if [ -z "$builder_NAMESPACE" ]; then
    builder_NAMESPACE="$builder_OUTPUT_NAME"
fi
if [ -n "$3" ]; then
    builder_NAMESPACE="$3"
fi

build_type=""
exclude_file=""
include_flags=""
has_cc="$(type "$builder_CC" &> /dev/null)"
has_as="$(type "$builder_AS" &> /dev/null)"
there_are_cpp_files=""

fetch_includes_from_flags()
{
    if [[ $builder_CC_FLAGS == *I* ]]; then
        res=$(echo "$builder_CC_FLAGS" | grep -oP '(?<=-I).*?(?=\s|$)' | tr '\n' ' ')
        res=${res%?}
        res="-I""${res// / -I}"
        include_flags="$res"
    fi

    if [[ $builder_CXX_FLAGS == *I* ]]; then
        res=$(echo "$builder_CXX_FLAGS" | grep -oP '(?<=I).*?(?=\s|$)' | tr '\n' ' ')
        res=${res%?}
        res="-I""${res// / -I}"
        include_flags="$include_flags $res"
    fi
}

gather_includes()
{
    if [ ! -d "include/$builder_NAMESPACE" ]; then
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

select_exclude_file()
{
    if [ -f "src/.exclude" ]; then
        exclude_file="src/.exclude"
    elif [ -f "src/.$1.exclude" ]; then
        exclude_file="src/.$1.exclude"
    fi
}

check_if_excluded()
{
    if [ ! -z "$exclude_file" ]; then
        regex="^$1$";regex=${regex//"/"/"\/"}
        excluded="$(grep -e $regex $exclude_file | wc -l)"
        return $excluded
    fi
    return 0
}

compile()
{
    if [[ $1 == *.c ]] && [ -n "$has_cc" ]; then
        compiler="$builder_CC"
        flags="$builder_CC_FLAGS"
    elif { [[ $1 == *.s ]] || [[ $1 == *.S ]]; } && [ -n "$has_as" ]; then
        compiler="$builder_AS"
        flags="$builder_AS_FLAGS"
    else
        compiler="$builder_CC"
        flags="$builder_CXX_FLAGS"
        there_are_cpp_files="1"
    fi

    if [ -n "$build_type" ]; then
        flags="-fPIC $flags"
    fi

    $compiler $flags -c "$1" -o "$2"
}

linking()
{
    if [ $there_are_cpp_files ]; then
        linker="$builder_CXX"
        flags="$builder_CXX_FLAGS"
    else
        linker="$builder_CC"
        flags="$builder_CC_FLAGS"
    fi
    
    if [ -z "$2" ]; then
        echo "Linking with $linker $builder_LD_FLAGS"
        echo "$1"
        $linker $builder_LD_FLAGS -o "output/$builder_OUTPUT_NAME" $1
    else
        echo "Linking with $linker $2 $builder_LD_FLAGS"
        echo "$1"
        dl_name="output/lib/lib$builder_OUTPUT_NAME"
        if [[ $build_type == *win* ]]; then
            dl_name="${dl_name}.dll"
        else
            dl_name="${dl_name}.so"
        fi
        $linker $flags $2 $builder_LD_FLAGS -o "$dl_name" $1
    fi
}

build()
{
    if [ ! -d "build" ]; then
      mkdir build
    fi

    select_exclude_file "$1"
    fetch_includes_from_flags

    build_type="$1"
    build_dsc="$build_type:$builder_CC_FLAGS:$builder_CXX_FLAGS:$builder_AS_FLAGS:$builder_LD_FLAGS"
    build_changed=0
    compiled_at_leat_one_file=0
    source_files="$(find $(pwd)/src -type f,l -iregex '.*\.\(c\|i\|ii\|cc\|cp\|cxx\|cpp\|CPP\|c++\|C\|s\|S\|sx\)' -printf 'src/%P ')"

    if [ -f "build/build.dsc" ]; then
        prev_build_dsc="$(cat build/build.dsc)"
        if [ "$build_dsc" != "$prev_build_dsc" ]; then build_changed=1; fi;
        if [ $build_changed -eq 1 ]; then
            echo "Rebuilding due to type or compile/linking flag changes."
        fi
    else
        build_changed=1
    fi
    echo -n "$build_dsc" > "build/build.dsc"

    IFS=' ' read -r -a sources <<< "$source_files"
    echo -e "Compiling:\n C with: $builder_CC $builder_CC_FLAGS\n C++ with: $builder_CXX $builder_CXX_FLAGS\n Assembler with: $builder_AS $builder_AS_FLAGS\n"

    for source_file in "${sources[@]}"
    do
        check_if_excluded "$(echo $source_file | cut -d'/' -f2-)"
        if [ $? == 1 ]; then
            echo -e "\t$source_file -> EXCLUDED"
            continue
        fi

        source_file_name=$(echo "$source_file" | cut -d'.' -f1)
        source_file_name=${source_file_name##*/}
        object_file_path="build/$source_file_name.o"
        file_has_changed=""

        if [ -f "$object_file_path" ]; then
            make_rule_of_dependencies=$($builder_CC $include_flags -MM "$source_file" | cut -d':' -f2- | tr '\n' ' ' )
            make_rule_of_dependencies="${make_rule_of_dependencies//'\'}"
            IFS=' ' read -r -a files_to_check <<< "$make_rule_of_dependencies"
            for file_to_check in "${files_to_check[@]}"
            do
                if [ $(stat -c %Y "$object_file_path") -lt $(stat -c %Y "$file_to_check") ]; then
                    file_has_changed="1"
                    break  
                fi
            done
        else
            file_has_changed="1"
        fi

        if [ $file_has_changed ] || [ $build_changed -eq 1 ]; then
            echo -e "\t$source_file -> $object_file_path"
            compile "$source_file" "$object_file_path"

            if [ $? -ne 0 ]; then
                echo "Build failed!"
                exit 1
            fi

            compiled_at_leat_one_file=1
        fi
    done
    echo ""
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
    echo -e "Usage: $0 (static|dynamic|dynamic_win|exec|clean|strip|help) [output_name] [namespace]\n\t(Everything between [] is optional.)\n"\
"Brief\n"\
"\tCompiles every source file from ./src directory then makes an executable or library file \n\tfrom compiled and other object(*.o) or archive(*.a) files from ./src into ./output.\n"\
"\tAlso exports every header file from ./src as soft link into ./include\n\n\t(recursive)\n"\
"Options\n"\
"\tstatic\t\t\t- Build static library\n"\
"\tdynamic\t\t\t- Build dynamic library \n"\
"\tdynamic_win\t\t- Build dynamic library but name it as <output_name>.dll\n"\
"\texec\t\t\t- Build executable\n"\
"\tclean\t\t\t- Clean build results\n"\
"\tstrip\t\t\t- Strips any executable or dynamic library from ./output (see strip --help)\n"\
"\thelp\t\t\t- Show this help\n"\
"Environment variables\n"\
"\tbuilder_CC\t\t - C compiler\t\t (default: gcc)\n"\
"\tbuilder_CXX\t\t - C++ compiler\t\t (default: g++)\n"\
"\tbuilder_AS\t\t - Assembler\t\t (default: as)\n"\
"\tbuilder_AR\t\t - archiver\t\t (default: ar)\n"\
"\tbuilder_CC_FLAGS\t - C compiler flags\t (default: -O3 -Wall)\n"\
"\tbuilder_CXX_FLAGS\t - C++ compiler flags\t (default: -O3 -Wall)\n"\
"\tbuilder_AS_FLAGS\t - Assembler flags\t (default: )\n"\
"\tbuilder_LD_FLAGS\t - linker flags\t\t (default: )\n"\
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
"\tsrc\t\t\t- Source files : *.(c|i|ii|cc|cp|cxx|cpp|CPP|c++|C|s|S|sx)\n"\
"Excluding files\n"\
"\tTo exclude source files a ./src/.exclude or ./src/.<build_type>.exclude file must exists.\n"\
"\tIf ./src/.exclude exists then it overrides every build type specific exclude file.\n"\
"\tAn exclude file should contain lines of relative pathes of files to exclude from ./src directory.\n"\

elif [ "$1" == "dynamic" ] || [ "$1" == "dynamic_win" ]; then
    echo "Dynamic build."

    build "$1"

    if [ $compiled_at_leat_one_file -ne 0 ]; then
        if [ ! -d "output/lib" ]; then
          mkdir -p output/lib
        fi
        
	    gather_object_files

	    linking "$object_files" "-shared"

	    if [ $? -ne 0 ]; then
	        echo "Build failed!"
	        exit 1
	    fi
        echo "Done."

        gather_includes
	else
		echo "Nothing has changed since the last build."
	fi
elif [ "$1" == "static" ]; then
    echo "Static build."
    
    build "$1"

    if [ $compiled_at_leat_one_file -ne 0 ]; then
        if [ ! -d "output/lib" ]; then
          mkdir -p output/lib
        fi

        gather_object_files
        
        echo "Linking static library"
        $builder_AR rvs "output/lib/lib$builder_OUTPUT_NAME.a" $object_files
        echo "Output: output/lib/lib$builder_OUTPUT_NAME.a"
        echo "Done."
        
        gather_includes
    else
        echo "Nothing has changed since the last build."
    fi
elif [ "$1" == "exec" ]; then
    echo "Building executable."

    build "$1"

    if [ $compiled_at_leat_one_file -ne 0 ]; then
        if [ ! -d "output" ]; then
          mkdir -p output
        fi
        
	    gather_object_files

	    linking "$object_files"

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
    if [ -z "$2" ] || [[ $2 == *-h* ]]; then
        echo -e "Usage: $0 $1 [OPTIONS]\n"\
"Options\n"\
"-h, --help\t - Show this help\n"\
"-a, --all\t - Strips all type of outputs(dynamic,static,exec)\n"\
"-s\t\t - Strips static library files\n"\
"-d\t\t - Strips dynamic library files\n"\
"-e\t\t - Strips executable output files\n"
    else
        if [[ $2 == *-a* ]]; then
            all_files_to_strip="$(find $(pwd)/output -type f -printf '%P ')"
        else
            regex=""
            if [[ $2 == *s* ]]; then
                regex="${regex}a\|"
            fi
            if [[ $2 == *d* ]]; then
                regex="${regex}so\|dll\|"
            fi

            if [ -n "$regex" ]; then
                regex=${regex%?}
                regex=".*\.\($regex)"
                all_files_to_strip="$(find $(pwd)/output/lib -type f -iregex $regex -printf 'lib/%P ')"
            fi
            
            if [[ $2 == *e* ]]; then
                exec_files=$(ls -p output | grep -v / | tr '\n' ' ')
                all_files_to_strip="$all_files_to_strip $exec_files"
            fi
        fi

        IFS=' ' read -r -a files_to_strip <<< "$all_files_to_strip"
        for file_to_strip in "${files_to_strip[@]}"
        do
            echo "strip --strip-unneeded $file_to_strip"
            strip --strip-unneeded "output/$file_to_strip"
        done
    fi
else
    echo "Unrecognized parameter: \"$1\"!"
fi

exit 0

