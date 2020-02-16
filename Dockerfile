FROM varnish:6

RUN apt update
RUN apt install -y nodejs

RUN mkdir /app
COPY app.js /app/app.js

CMD ["/usr/bin/nodejs", "/app/app.js"]