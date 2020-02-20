FROM varnish:6

WORKDIR /

RUN apt update
RUN apt install -y curl

RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - 
RUN apt install -y nodejs

RUN npm install -y mustache

COPY daemon.js /daemon.js
COPY empty.vcl /etc/varnish/empty.vcl
COPY wordpress.vcl /etc/varnish/wordpress.vcl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]

WORKDIR /etc/varnish