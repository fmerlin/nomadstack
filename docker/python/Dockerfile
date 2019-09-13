FROM clearlinux/python
COPY requirements.txt /requirements.txt

RUN swupd bundle-add uwsgi &&\
    pip3 install -r /requirements.txt
