#!/bin/bash
usage() {
    cat<<USAGE
Usage: ${0##*/} [options] <addon>

Options:
    -h, --help
        Print this message and exit.
    --tag=<tag>
        Specify image tag, overides value in <addon>/VERSION file.

Examples:
    ./${0##*/} kube-state-metrics
    ./${0##*/} --tag=$(whoami)-dev kube-state-metrics
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
        exit
esac

source "$ADDON/VERSION"

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
        $ADDON)
            # skip
            ;;
        *)
            echo "Invalid option: $option"
            usage
            ;;
    esac
done

docker push $REPO/$NAME-$ADDON:$VERSION
