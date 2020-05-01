#!/bin/bash

usage (){
    echo -en "Usage: $0 -e [SENTRY_EMAIL default:root@example.com] "\
        "-p [SENTRY_PASSWORD default:12341234] -s [SENTRY_PORT default:80]"\
        "-d [POSTGRES_DATA default:/data/postgres/sentry] -h<help>\n" 1>&2
    echo -en "For example:\n"
    echo -en "1.common\n"
    echo -en "  $0 -e liuxu@dlyunzhi.com -p 12341234 -s 8080\n\n"
    echo -en "2.specify postgres data path\n"
    echo -en "  $0 -d /root/data\n\n"
    exit ${STATE_WARNING}
}

while getopts e:p:s:d:h opt
do
        case "$opt" in
        e) SENTRY_EMAIL=$OPTARG;;
        p) SENTRY_PASSWORD="$OPTARG";;
        s) SENTRY_PORT="$OPTARG";;
        d) POSTGRES_DATA="$OPTARG";;
        h) usage;;
        *) usage;;
        esac
done

if [ -z ${SENTRY_EMAIL} ]; then
    SENTRY_EMAIL=root@example.com
fi

if [ -z ${SENTRY_PASSWORD} ]; then
    SENTRY_PASSWORD=12341234
fi

if [ -z ${SENTRY_PORT} ]; then
    SENTRY_PORT=80
fi

if [ -z ${POSTGRES_DATA} ]; then
    POSTGRES_DATA=/data/postgres/sentry
fi

SENTRY_SECRET=`docker run --rm sentry config generate-secret-key`
POSTGRES_NAME=sentry-postgres
POSTGRES_SECRET=abcd1234
REDIS_NAME=sentry-redis
SENTRY_NAME=sentry-service
SENTRY_CRON_NAME=sentry-cron
SENTRY_WORKER_NAME=sentry-worker

# install expect
if [ -z "$(dpkg -l | grep expect)" ];then
    echo -n "install expect"
    apt-get install -y expect
fi


# run redis service
if [ "$(docker ps | grep $REDIS_NAME)" ];then
    echo -n "docker kill "
    docker kill $REDIS_NAME
    sleep 1
fi

docker run -d --rm --name sentry-redis redis

# run postgres service
if [ "$(docker ps | grep $POSTGRES_NAME)" ];then
    echo -n "docker kill "
    docker kill $POSTGRES_NAME
    sleep 1
fi

mkdir -p ${POSTGRES_DATA}
docker run -d --rm --name $POSTGRES_NAME -v ${POSTGRES_DATA}:/var/lib/postgresql/data/ \
-e POSTGRES_PASSWORD=$POSTGRES_SECRET -e POSTGRES_USER=sentry postgres

# sentry upgrade
expect << EOF
set timeout -1
spawn docker run -it --rm -e SENTRY_SECRET_KEY='$SENTRY_SECRET' \
--link sentry-postgres:postgres --link sentry-redis:redis \
sentry upgrade
expect "create a user account"
send "Y\r"
expect "Email"
send "${SENTRY_EMAIL}\r"
expect "Password"
send "${SENTRY_PASSWORD}\r"
expect "Repeat for confirmation"
send "${SENTRY_PASSWORD}\r"
EOF

if [ "$(docker ps | grep $SENTRY_NAME)" ];then
    echo -n "docker kill "
    docker kill $SENTRY_NAME
    sleep 1
fi
docker run -d --rm --name $SENTRY_NAME -p ${SENTRY_PORT}:9000 -e SENTRY_SECRET_KEY=${SENTRY_SECRET} --link sentry-redis:redis --link sentry-postgres:postgres sentry

if [ "$(docker ps | grep $SENTRY_CRON_NAME)" ];then
    echo -n "docker kill "
    docker kill $SENTRY_CRON_NAME
    sleep 1
fi
docker run -d --rm --name $SENTRY_CRON_NAME -e SENTRY_SECRET_KEY=${SENTRY_SECRET} --link sentry-postgres:postgres --link sentry-redis:redis sentry run cron

if [ "$(docker ps | grep $SENTRY_WORKER_NAME)" ];then
    echo -n "docker kill "
    docker kill $SENTRY_WORKER_NAME
    sleep 1
fi
docker run -d --rm --name $SENTRY_WORKER_NAME -e SENTRY_SECRET_KEY=${SENTRY_SECRET} --link sentry-postgres:postgres --link sentry-redis:redis sentry run worker

exit 0




