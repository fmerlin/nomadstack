Redis = require('../src/redis-ws');

var client = Redis('wss://localhost/toto_ws');

client.socket.onpen = test(
    'test add',
    () => {
        client.psubscribe('celery-meta-task-*', 'json');
        client.call('celery', 'add', 1, 2).on('task-succeeded', (msg) => {
            client.get(msg.id, 'json').on('ok', (msg) => {
                expect(msg.data, 3);
            });
        });
    }
);