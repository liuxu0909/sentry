you need docker first!!!

Usage: ./install.sh -e [SENTRY_EMAIL default:root@example.com]  -p [SENTRY_PASSWORD default:12341234] -s [SENTRY_PORT default:80] -d [POSTGRES_DATA default:/data/postgres/sentry] -h<help>
For example:
1.common
  ./install.sh -e liuxu@dlyunzhi.com -p 12341234 -s 8080

2.specify postgres data path
  ./install.sh -d /root/data
