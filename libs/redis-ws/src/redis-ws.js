var events = require('events'),
    uuid = require('uuid');

function Redis(url) {
    var self = this;
    self.socket = new WebSocket(url);
    self.results = results;

    this.socket.onmessage = function (event) {
        var msg = JSON.parse(event.data);
        var id = msg.id;
        var result = self.results[id];
        if (result) {
            result.emit(msg.status, msg);
            if (msg.action !== 'read_reply' ||
                msg.status === 'task-succeeded' ||
                msg.status === 'task-failed' ||
                msg.status === 'task-revoked'
            ) {
                delete self.results[id];
            }
        }
    };
}

Redis.prototype.execute = function (msg) {
    this.socket.send(JSON.stringify(msg));
    if (msg.id) {
        var res = new events.EventEmitter();
        this.results[msg.id] = res;
        return res;
    }
};

Redis.prototype.call = function (queue, task, args, kwargs, options) {
    return this.execute({
        action: 'lpush',
        task: task,
        args: args || [],
        id: uuid.v4(),
        options: options,
        kwargs: kwargs || {},
        queue: queue,
        encoding: 'celery_message'
    });
};

Redis.prototype.publish = function (channel, data, encoding) {
    return this.execute({
        action: 'publish',
        channel: channel,
        encoding: encoding,
        data: data
    });
};

Redis.prototype.psubscribe = function (channel, encoding) {
    return this.execute({
        action: 'psubscribe',
        channel: channel,
        encoding: encoding || 'json',
        id: uuid.v4()
    });
};

Redis.prototype.get = function (key, encoding) {
    return this.execute({
        action: 'get',
        key: key,
        encoding: encoding,
        id: uuid.v4()
    });
};

Redis.prototype.set = function (key, data, encoding) {
    return this.execute({
        action: 'set',
        key: key,
        encoding: encoding,
        data: data
    });
};

Redis.prototype.lpush = function (queue, data, encoding) {
    return this.execute({
        action: 'lpush',
        key: key,
        encoding: encoding,
        data: data
    });
};

Redis.prototype.lpop = function (queue, encoding) {
    return this.execute({
        action: 'lpop',
        key: key,
        encoding: encoding,
        data: data,
        id: uuid.v4()
    });
};

module.exports = Redis;
