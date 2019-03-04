FROM phusion/baseimage:0.11

MAINTAINER csek06

VOLUME ["/config"]

RUN export DEBCONF_NONINTERACTIVE_SEEN=true DEBIAN_FRONTEND=noninteractive && \
apt-get update && \
apt-get install -y \
libaio1 numactl tzdata && \
usermod -u 99 nobody && \
usermod -g 100 nobody && \
mkdir -p /etc/my_init.d && \
mkdir -p /config/your-platform-install

COPY firstrun.sh /etc/my_init.d/firstrun.sh
COPY install-scripts/ /tmp/your-platform-install/
COPY startup-scripts/ /tmp/your-platform-install/

RUN chmod +x /etc/my_init.d/firstrun.sh

EXPOSE 9191 8090 8181 9080 9081 7001 7002