FROM varnish:6

RUN apt update
RUN apt install -y nodejs

COPY daemon.js /daemon.js
COPY empty.vcl /etc/varnish/empty.vcl
COPY wordpress.vcl /etc/varnish/wordpress.vcl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]