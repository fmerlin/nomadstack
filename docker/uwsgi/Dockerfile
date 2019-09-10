FROM clearlinux/python
COPY requirements.txt /requirements.txt

RUN swupd bundle-add uwsgi &&\
    pip3 install -r /requirements.txt

ENV UWSGI_VASSAL_SOCKET /run/uwsgi/*.socket

ADD app /app
VOLUME /app

EXPOSE 8089
WORKDIR /app
ENTRYPOINT ["uwsgi", "--json", "/app/uwsgi.json"]
