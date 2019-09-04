FROM postgres:9.6.13
ENV PATH=/usr/local/pgsql/bin/:$PATH

COPY etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/pgdg.list
ADD https://packagecloud.io/install/repositories/timescale/timescaledb/script.deb.sh /root/

RUN apt update \
 && bash </root/script.deb.sh \
 && apt install -y --no-install-recommends python-dev libpq-dev postgresql-plpython3-9.6 postgresql-9.6-pllua postgresql-contrib-9.6 git build-essential python-pip pgxnclient postgresql-server-dev-9.6 timescaledb-postgresql-9.6 \
 && pip install setuptools \
 && pgxn install multicorn \
 && pip install cassandra-driver pytz pg_es_fdw psycopg2 python-consul redis cloudant\
 && cd /root \
 && git clone https://github.com/rankactive/cassandra-fdw.git \
 && git clone https://github.com/Vonng/hbase_fdw.git \
 && cd /root/cassandra-fdw \
 && python setup.py install \
 && cp -r /root/hbase_fdw/hbase_fdw /usr/local/lib/python2.7/site-packages/
