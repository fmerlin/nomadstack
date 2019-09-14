var url = require('url'),
    events = require('events'),
    uuid = require('uuid');

function Client(url) {
    var results = {};
    this.socket = new WebSocket(url);
    this.results = results;

    this.socket.onopen = function (e) {
        alert("[open] Connection established");
    };

    this.socket.onmessage = function (event) {
        var id = event.data.id;
        var result = results[id];
        if (result) {
            result.emit(event.data.type, event.data.result);
            delete results[id];
        }
    };

    this.socket.onclose = function (event) {
        if (event.wasClean) {
            alert(`[close] Connection closed cleanly, code=${event.code} reason=${event.reason}`);
        } else {
            // e.g. server process killed or network down
            // event.code is usually 1006 in this case
            alert('[close] Connection died');
        }
    };

    this.socket.onerror = function (error) {
        alert(`[error] ${error.message}`);
    };
}

Client.prototype.call = function(task, args, kwargs, options) {
    args = args || [];
    kwargs = kwargs || {};
    var id = uuid.v4();

    var message = {
        task: task,
        args: args,
        kwargs: kwargs
    };
    var payload = {
            body: new Buffer(message).toString('base64'),
            headers: {},
            'content-type': options.contentType,
            'content-encoding': options.contentEncoding,
            properties: {
                body_encoding: 'base64',
                correlation_id: id,
                delivery_info: {
                    exchange: queue,
                    priority: 0,
                    routing_key: queue
                },
                delivery_mode: 2, // No idea what this means
                delivery_tag: uuid.v4(),
                reply_to: uuid.v4()
            }
        };
        this.socket.send(JSON.stringify(payload));
        res = new EventEmitter();
        this.results[id] = res;
        return res;

};