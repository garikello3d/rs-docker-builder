#!/bin/bash

set -e

function usage {
    printf "to prepare docker build image:\n\t$0 app_name --image [os_ident]\n"
    printf "to build the application based on previousely built image:\n\t$0 app_name --app [os_ident]\n"
    exit 1
}

function trim {
    echo -n "$1" | sed 's/^[[:space:]]\+//g;s/[[:space:]]\+$//g'
}

APP_NAME=$1
OS=$3

if [ $# -ne 3 ] ; then
    usage
    exit 1
fi

cat PLATFORMS | sed '/^#/d;/^[[:space:]]*$/d' | while IFS="|" read IDENT FROM PAC_UPD PAC_INST; do
    if [[ -z "$IDENT" || -z "$FROM" || -z "$PAC_UPD" || -z "$PAC_INST" ]] ; then
        echo invalid line in PLATFORMS
        exit 1
    fi
    
    IDENT=$(trim "$IDENT")
    FROM=$(trim "$FROM")
    PAC_UPD=$(trim "$PAC_UPD")
    PAC_INST=$(trim "$PAC_INST")

    if [ -n "$OS" ]; then
        if [ "x$OS" != "x$IDENT" ]; then
            continue
        fi
    fi

    TYPE=$(echo $FROM | cut -f1 -d/)
    HOST=$(echo $FROM | cut -f2,3 -d/)
    TO_INSTALL=$(cat INSTALL_SPEC)

    cd ..
    case $2 in 
        --image)
            case $TYPE in
                docker)
                    echo preparing docker build image for $IDENT on platform $HOST
                    docker build -t $APP_NAME-$IDENT --ulimit nofile=1024:262144 -f rs-docker-builder/Dockerfile.template \
                        --build-arg OS=$HOST \
                        --build-arg PAC_UPD="$PAC_UPD" \
                        --build-arg PAC_INST="$PAC_INST" \
                        .
                    # NOTE needed to decrease the open file limit, otherwise yum can go crazy
                    # (see https://bugzilla.redhat.com/show_bug.cgi?id=1537564)
                    ;;
                remote)
                    echo preparing remote maching for $IDENT
                    rs-docker-builder/install-to-remote.sh "$HOST" "$PAC_INST"
                    ;;
                *)
                    echo invalid \"from\" type: \"$TYPE\"
                    exit 5
            esac
            ;;
        --app)
            TMP_DIR=$(mktemp -d /tmp/$APP_NAME-XXX)
            DIST_DIR=$TMP_DIR/dist
            mkdir $DIST_DIR
            for F in $TO_INSTALL; do cp -av "$F" $DIST_DIR/ ; done
            (cd $DIST_DIR && tar cf $TMP_DIR/sources.tar . )
            rm -rf $DIST_DIR
            OUT_DIR=rs-docker-builder/build/$IDENT
            mkdir -p $OUT_DIR

            case $TYPE in
                docker)
                    echo building application in docker for $IDENT
                    docker run -v=$TMP_DIR:/src --ulimit nofile=1024:262144 $APP_NAME-$IDENT /bin/bash -l -c "/build-internal.sh /src"
                    cp -v $TMP_DIR/target/release/$APP_NAME $OUT_DIR/
                    ;;
                remote)
                    echo building application in remote machine for $IDENT
                    ssh $HOST -- "rm -rf src/ ; mkdir src/"
                    scp $TMP_DIR/sources.tar $HOST:src/
                    ssh $HOST -- "./build-internal.sh ./src"
                    scp $HOST:src/target/release/$APP_NAME $OUT_DIR/
                    ;;
                *)
                    echo invalid \"from\" type: \"$TYPE\"
                    exit 5
            esac
            echo binary for $IDENT is ready in $OUT_DIR
            rm -rf $DIST_DIR
            ;;
        *)
            echo incorrect mode
            usage
    esac
    cd rs-docker-builder
done

echo all done
