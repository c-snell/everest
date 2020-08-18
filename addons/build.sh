#!/bin/bash
usage() {
    cat<<USAGE
Usage: ${0##*/} [options] <addon>

Options:
    -h, --help
        Print this message and exit.
    --tag=<tag>
        Specify image tag, overides value in <addon>/VERSION file.
    --no-cache
        Build container image without using docker cache.

Examples:
    ./${0##*/} kube-state-metrics
    ./${0##*/} --no-cache --tag=$(whoami)-dev kube-state-metrics
USAGE
exit 64 #EX_USAGE
}

source "addon-common.sh"

# Last positional arg must be the addon name.
ADDON="${@: -1}"
validate_addon $ADDON
case $? in
    64)
        usage
        ;;
    1)
        exit 1
esac

source "$ADDON/VERSION"

if [[ -n ${HTTP_PROXY} ]];
then
    ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --build-arg=HTTP_PROXY=${HTTP_PROXY}"
elif [[ -n ${http_proxy} ]];
then
    ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --build-arg=HTTP_PROXY=${http_proxy}"
fi

# Parse options, ignore positional arg.
for option in "$@"; do
    case $option in
        -h|--help)
            usage
            ;;
        --tag=*)
            VERSION="${option#*=}"
            shift
            ;;
        --no-cache)
            ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --no-cache"
            ;;
        $ADDON)
            #skip
            ;;
        *)
            echo "Invalid option: $option"
            usage
            ;;
    esac
done

docker build ${ADDITIONAL_ARGS} -t $REPO/$NAME-$ADDON:$VERSION $ADDON
