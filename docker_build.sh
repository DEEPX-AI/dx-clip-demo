#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
DX_AS_PATH=$(realpath -s "${SCRIPT_DIR}")

# color env settings
source ${DX_AS_PATH}/scripts/color_env.sh

pushd "$DX_AS_PATH"

OUTPUT_DIR="$DX_AS_PATH/archives"
UBUNTU_VERSION=""

INTERNAL_MODE=0

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") OPTIONS(--ubuntu_version=<version> [--help]"
    echo "Example 1) $0 --ubuntu_version=24.04"
    echo "Example 3) $0 --ubuntu_version=24.04 --driver_update"
    echo "Options:"
    echo "  --ubuntu_version=<version>     : Specify Ubuntu version (ex> 24.04)"
    echo "  [--driver_update]              : Install 'dx_rt_npu_linux_driver' in the host environment"
    echo "  [--no-cache]                   : Build Docker images freshly without cache"
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

docker_build_impl()
{
    local target=$1
    local config_file_args=${2:--f docker/docker-compose.yml}
    local no_cache_arg=""

    if [ ${INTERNAL_MODE} -eq 1 ]; then
        config_file_args="${config_file_args} -f docker/docker-compose.internal.yml"
    fi

    if [ "$NO_CACHE" = "y" ]; then
        no_cache_arg="--no-cache"
    fi

    # Build Docker image
    export COMPOSE_BAKE=true
    export UBUNTU_VERSION=${UBUNTU_VERSION}
    if [ ! -n "${XAUTHORITY}" ]; then
        echo -e "${TAG_INFO} XAUTHORITY env is not set. so, try to set automatically."
        DUMMY_XAUTHORITY="/tmp/dummy"
        touch ${DUMMY_XAUTHORITY}
        export XAUTHORITY=${DUMMY_XAUTHORITY}
        export XAUTHORITY_TARGET=${DUMMY_XAUTHORITY}
    else
        echo -e "${TAG_INFO} XAUTHORITY(${XAUTHORITY}) is set"
        export XAUTHORITY_TARGET="/tmp/.docker.xauth"
    fi

    CMD="docker compose ${config_file_args} build ${no_cache_arg} dx-${target}"
    echo "${CMD}"

    ${CMD} || { echo -e "${TAG_ERROR} docker build '${target} failed. "; exit 1; }
}

docker_build_dx-clip-demo()
{
    local docker_compose_args="-f docker/docker-compose.yml"
    docker_build_impl "clip-demo" "${docker_compose_args}"
}

install_dx_rt_npu_linux_driver() 
{
    CMD="./dx-runtime/install.sh --target=dx_rt_npu_linux_driver"
    echo "${CMD}"

    ${CMD}
}

main() {
    # usage
    if [ -z "$UBUNTU_VERSION" ]; then
        show_help "error" "--ubuntu_version ($UBUNTU_VERSION) does not exist."
    else
        echo -e "${TAG_INFO} UBUNTU_VERSSION($UBUNTU_VERSION) is set."
        if [ "$DRIVER_UPDATE" = "y" ]; then
            echo -e "${TAG_INFO} DRIVER_UPDATE($DRIVER_UPDATE) is set."
        fi
        if [ "$NO_CACHE" = "y" ]; then
            echo -e "${TAG_INFO} NO_CACHE($NO_CACHE) is set."
        fi
    fi

    echo "Archiving dx-clip-demo"
    ${DX_AS_PATH}/scripts/archive_git_repos.sh || { echo -e "${TAG_ERROR} Archiving dx-clip-demo failed.\n${TAG_INFO} ${COLOR_BRIGHT_YELLOW_ON_BLACK}Please try running 'git submodule update --init --recursive --force' and then try again.${COLOR_RESET}"; exit 1; }
    docker_build_dx-clip-demo
    if [ "$DRIVER_UPDATE" = "y" ]; then
        install_dx_rt_npu_linux_driver
    fi

    # remove archives
    # if [[ -d "$OUTPUT_DIR" ]]; then
    #     echo "Removing archive directory: $OUTPUT_DIR"
    #     rm -rf "$OUTPUT_DIR"
    # fi
}

# parse args
for i in "$@"; do
    case "$1" in
        --ubuntu_version=*)
            UBUNTU_VERSION="${1#*=}"
            ;;
        --driver_update)
            DRIVER_UPDATE=y
            ;;
        --no-cache)
            NO_CACHE=y
            ;;
        --help)
            show_help
            exit 0
            ;;
        --internal)
            INTERNAL_MODE=1
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
