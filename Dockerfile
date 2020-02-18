FROM varnish:6

RUN apt update
RUN apt install -y nodejs

RUN mkdir /app
COPY app.js /app/app.js
COPY default.vcl /etc/varnish/default.vcl
COPY wordpress.vcl /etc/varnish/wordpress.vcl

CMD ["/usr/bin/nodejs", "/app/app.js"]