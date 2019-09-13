from elasticsearch import Elasticsearch

es = Elasticsearch(hosts=[dict(host='192.168.56.10', port=9200)])

res = es.search(index="logstash-2019.09.12", body=dict(query=dict(
#    range={"@timestamp": dict(gte='now-1H', lt='now')},
    match={"status": "200" }
)))

res = dict()
for h in res["hits"]["hits"]:
    s = h['_source']
    k = (s["service"], s["upstream"])
    res[k] = res.get(k, 0) + s["duration"]
