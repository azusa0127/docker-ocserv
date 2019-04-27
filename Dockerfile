FROM alpine:3.9

ENV OC_VERSION=0.12.3

RUN apk add --no-cache --virtual .build-deps \
  curl\
  g++\
  gnutls-dev\
  gpgme\
  libev-dev\
  libnl3-dev\
  libseccomp-dev\
  linux-headers\
  linux-pam-dev\
  lz4-dev\
  make\
  readline-dev\
  tar\
  xz

RUN curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz

RUN curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz.sig" -o ocserv.tar.xz.sig \
	&& gpg --keyserver pgp.mit.edu --recv-key 7F343FA7 \
	&& gpg --keyserver pgp.mit.edu --recv-key 96865171 \
	&& gpg --verify ocserv.tar.xz.sig

RUN mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz*

WORKDIR /usr/src/ocserv

RUN ./configure && make && make install

RUN mkdir -p /etc/ocserv && cp /usr/src/ocserv/doc/sample.config /etc/ocserv/ocserv.conf

RUN rm -rf /usr/src/ocserv

RUN apk del .build-deps

RUN apk add --no-cache \
  gnutls\
  libev\
  libseccomp\
  linux-pam\
  lz4-libs\
  musl\
  nettle\
  gnutls-utils\
  iptables\
  libnl3\
  readline

WORKDIR /etc/ocserv

# Setup config
COPY groupinfo.txt /tmp/

RUN set -x \
	&& sed -i 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\(max-same-clients = \)2/\110/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\.\.\/tests/\/etc\/ocserv/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/#\(compression.*\)/\1/' /etc/ocserv/ocserv.conf \
	&& sed -i '/^ipv4-network = /{s/192.168.1.0/192.168.99.0/}' /etc/ocserv/ocserv.conf \
	&& sed -i 's/192.168.1.2/8.8.8.8/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^route/#route/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^no-route/#no-route/' /etc/ocserv/ocserv.conf \
	&& sed -i '/\[vhost:www.example.com\]/,$d' /etc/ocserv/ocserv.conf \
	&& mkdir -p /etc/ocserv/config-per-group \
	&& cat /tmp/groupinfo.txt >> /etc/ocserv/ocserv.conf \
	&& rm -f /tmp/cn-no-route.txt \
	&& rm -f /tmp/groupinfo.txt

COPY All /etc/ocserv/config-per-group/All

COPY cn-no-route.txt /etc/ocserv/config-per-group/Route

COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443

CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
