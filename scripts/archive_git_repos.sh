#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
DX_AS_PATH=$(realpath -s "${SCRIPT_DIR}/..")

pushd $DX_AS_PATH

# color env settings
source ${DX_AS_PATH}/scripts/color_env.sh

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") [--help]"
    echo "Options:"
    echo "  [--help]                       : Show this help message"

    if [ "$1" == "error" ] && [[ ! -n "$2" ]]; then
        echo -e "${TAG_ERROR} Invalid or missing arguments."
        exit 1
    elif [ "$1" == "error" ] && [[ -n "$2" ]]; then
        echo -e "${TAG_ERROR} $2"
        exit 1
    elif [[ "$1" == "warn" ]] && [[ -n "$2" ]]; then
        echo -e "${TAG_WARN} $2"
        return 0
    fi
    exit 0
}

git_archive() {
    local base_path=$1
    local dir_name=$(basename "$base_path")

    if [ -f "$base_path/.git" ] || [ -d "$base_path/.git" ]; then
        archive_file="$OUTPUT_DIR/${dir_name}.tar.gz"
        echo -e "${TAG_INFO} Archiving repository: $dir_name"
        (cd "$base_path" && git archive --format=tar.gz --output="$archive_file" $(git symbolic-ref --short HEAD || git rev-parse HEAD))
        if [[ $? -eq 0 ]]; then
            echo -e "${TAG_SUCC} Archive created successfully: $archive_file"
            return 0
        else
            echo -e "${TAG_WARN} Failed to create archive for: $dir_name"
            return 2
        fi
    else
        echo -e "${TAG_WARN} No .git directory found in: $dir_name"
        return 1
    fi
}

git_archive_from_subdirs() {
    local base_path="$1"           # First argument is the target directory name (string)
    shift                            # Remove the first argument, remaining args will be in "$@"
    local target_subdirs=("$@")      # Store remaining arguments as an array of target directories

    echo -e "=== Archiving ${base_path} ... ${TAG_START} ==="

    for dir_name in "${target_subdirs[@]}"; do
        local subdir="${base_path}/${dir_name}"

        if [ -d "$subdir" ]; then
            git_archive "$subdir"
            local ret=$?
            echo "git_archive return code: $ret"
            if [ $ret -ne 0 ]; then
                echo -e "${TAG_ERROR} Archiving $subdir failed!"
                return $ret
            fi
        else
            echo -e "${TAG_ERROR} Directory does not exist, dir_name: $dir_name"
            return 1
        fi
    done

    echo -e "=== Archiving ${base_path} ... ${TAG_DONE} ==="
    return 0
}

archive_clip-demo() {
    DXRT_TARGET_DIRS=("dx_rt")
    git_archive_from_subdirs "${DX_AS_PATH}/dx-runtime" "${DXRT_TARGET_DIRS[@]}"
    if [ $? -ne 0 ]; then
        echo -e "${TAG_ERROR} Archiving dx-runtime / dx_rt failed!"
        exit 1
    fi
    
    git_archive "${DX_AS_PATH}/dx-clip-demo"
    if [ $? -ne 0 ]; then
        echo -e "${TAG_ERROR} Archiving dx-clip-demo failed!"
        exit 1
    fi
}

main() {
    echo -e "${TAG_INFO} TARGET_ENV($TARGET_ENV) is set."

    OUTPUT_DIR="$DX_AS_PATH/archives"
    mkdir -p "$OUTPUT_DIR"

    archive_clip-demo
}

# parse args
for i in "$@"; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${TAG_ERROR}: Invalid option '$1'"
            show_help
            exit 1
            ;;
    esac
    shift
done

main

popd

exit 0
