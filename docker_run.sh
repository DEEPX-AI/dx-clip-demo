#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
DX_AS_PATH=$(realpath -s "${SCRIPT_DIR}")

# color env settings
source ${DX_AS_PATH}/scripts/color_env.sh

pushd "$DX_AS_PATH"

OUTPUT_DIR="$DX_AS_PATH/archives"
UBUNTU_VERSION=""

USE_VOLUME=0
DEV_MODE=0
INTEL_GPU_HW_ACC=0

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") OPTIONS(--ubuntu_version=<version> [--help]"
    echo "Example:1) $0 --ubuntu_version=24.04"
    echo "Options:"
    echo "  --ubuntu_version=<version>     : Specify Ubuntu version (ex> 24.04)"
    echo "  [--use-volume]                 : Mount the workspace directory to the container"
    echo "                                   - Setup of dx-clip-demo will be skipped. "
    echo "                                   - You'll need to set it up after the container is running."
    echo "                                   - This opion helps to reduce the final Docker image size."
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

check_xdg_sesstion_type()
{
    echo -e "${TAG_INFO} XDG_SESSION_TYPE: $XDG_SESSION_TYPE"
    if [ "$XDG_SESSION_TYPE" == "tty" ]; then
        echo -e "${TAG_WARN} ${COLOR_BRIGHT_YELLOW_ON_BLACK}You are currently running in a **tty session**, which does not support GUI. In such environments, it is not possible to visually confirm the results of example code execution via GUI. (Note): ${COLOR_RESET}"
        echo -e -n "${TAG_INFO} ${COLOR_BRIGHT_GREEN_ON_BLACK}Press any key and hit Enter to continue. ${COLOR_RESET}"
        read -r answer
        echo -e "${TAG_INFO} Start docker run ..."

    elif [ "$XDG_SESSION_TYPE" != "x11" ]; then
        echo -e "${TAG_WARN} ${COLOR_BRIGHT_YELLOW_ON_BLACK}it is recommended to use an **X11 session (with .Xauthority support)** when working with the 'dx-all-suite' container.${COLOR_RESET}"
        echo -e "${TAG_WARN} ${COLOR_BRIGHT_YELLOW_ON_BLACK}For more details, please refer to the [FAQ section of the dx-all-suite documentation](https://github.com/DEEPX-AI/dx-all-suite/blob/main/docs/source/faq.md).${COLOR_RESET}"

        echo -e "${COLOR_BRIGHT_GREEN_ON_BLACK}if the user's host environment is not based on **X11 (with .Xauthority)** but instead uses **Xwayland** or similar, the 'xauth' data may be lost after a system reboot or session logout. As a result, the authentication file mount between the host and the container may fail, making it impossible to restart or reuse the container.${COLOR_RESET}"
        echo -e -n "${COLOR_RED_ON_BLACK}This may cause issues. Do you still want to continue? (y/n): ${COLOR_RESET}"
        read -r answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            echo -e "${TAG_INFO} Start docker run ..."
        else
            echo -e "${TAG_INFO} Docker run has been canceled."
            exit 1
        fi
    fi
}

docker_run_impl()
{
    local target=$1
    local config_file_args=${2:--f docker/docker-compose.yml}

    if [ ${USE_VOLUME} -eq 1 ]; then
        config_file_args="${config_file_args} -f docker/docker-compose.use-volume.yml"
    fi

    if [ ${DEV_MODE} -eq 1 ]; then
        config_file_args="${config_file_args} -f docker/docker-compose.dev.yml"
    fi

    # Run Docker Container
    export COMPOSE_BAKE=true
    export UBUNTU_VERSION=${UBUNTU_VERSION}
    DUMMY_XAUTHORITY=""
    if [ ! -n "${XAUTHORITY}" ]; then
        echo -e "${TAG_INFO} XAUTHORITY env is not set. so, try to set automatically."
        DUMMY_XAUTHORITY="${DX_AS_PATH}/dummy_xauthority"
        rm -rf ${DUMMY_XAUTHORITY}
        touch ${DUMMY_XAUTHORITY}
        export XAUTHORITY=${DUMMY_XAUTHORITY}
        export XAUTHORITY_TARGET=${DUMMY_XAUTHORITY}
    else
        echo -e "${TAG_INFO} XAUTHORITY(${XAUTHORITY}) is set"
        export XAUTHORITY_TARGET="/tmp/.docker.xauth"
    fi

    CMD="docker compose ${config_file_args} up -d --remove-orphans dx-${target}"
    echo "${CMD}"

    ${CMD}

    if [ "$XDG_SESSION_TYPE" == "tty" ]; then
        local DOCKER_EXEC_CMD="docker exec -it dx-${target}-${UBUNTU_VERSION} touch /deepx/tty_flag"

        echo -e "${DOCKER_EXEC_CMD}"
        ${DOCKER_EXEC_CMD}
    elif [ -n "${DUMMY_XAUTHORITY}" ]; then
        echo -e "${TAG_INFO} Adding xauth into docker container"

        # remove 'localhost' or 'LOCALHOST' in DISPLAY env var
        if [[ "$DISPLAY" == localhost:* ]]; then
            export DISPLAY=${DISPLAY#localhost}
        elif [[ "$DISPLAY" == LOCALHOST:* ]]; then
            export DISPLAY=${DISPLAY#LOCALHOST}
        fi

        XAUTHORITY=~/.Xauthority
        export XAUTHORITY
        XAUTH=$(xauth list "$DISPLAY")
        XAUTH_ADD_CMD="xauth add $XAUTH"
        
        local DOCKER_EXEC_CMD1="docker exec -it dx-${target}-${UBUNTU_VERSION} touch /tmp/.docker.xauth"
        local DOCKER_EXEC_CMD2="docker exec -it dx-${target}-${UBUNTU_VERSION} ${XAUTH_ADD_CMD}"

        echo -e "${DOCKER_EXEC_CMD1}"
        echo -e "${DOCKER_EXEC_CMD2}"
        ${DOCKER_EXEC_CMD1}
        ${DOCKER_EXEC_CMD2}
    fi
}

docker_run_dx-clip-demo()
{
    local docker_compose_args="-f docker/docker-compose.yml"
    docker_run_impl "clip-demo" "${docker_compose_args}"
}

main() {
    # usage
    if [ -z "$UBUNTU_VERSION" ]; then
        show_help "error" "--ubuntu_version ($UBUNTU_VERSION) does not exist."
    else
        echo -e "${TAG_INFO} UBUNTU_VERSSION($UBUNTU_VERSION) is set."
    fi

    check_xdg_sesstion_type

    echo "Installing dx-clip-demo"
    docker_run_dx-clip-demo
}

# parse args
for i in "$@"; do
    case "$1" in
        --ubuntu_version=*)
            UBUNTU_VERSION="${1#*=}"
            ;;
        --use-volume)
            USE_VOLUME=1
            ;;
        --help)
            show_help
            exit 0
            ;;
        --dev)
            DEV_MODE=1
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
