if [[ "$1" == "--update" ]]; then
    shift
    ssc::self_update "$@"
    exit $?
fi
