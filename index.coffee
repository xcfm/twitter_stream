Twit = require 'twit'
Hapi = require 'hapi'
SocketIO = require 'socket.io'

T = new Twit
  consumer_key: 'Ajo6EPWGlNUOmT930EGPmAh5a'
  consumer_secret: 'XrwPRGUpG2H5SwvVLaB2w8t3Ex4iNjAWmsU782q4k0YOq4t2zr'
  access_token: '728797696958423041-6qKF5lGF6OWV76l17OU4HXoCLb7hzuG'
  access_token_secret: 'J8HoGgsk7x7onTH6mYYgkCiC9oHCo95Y6NfGE2eN2XYSP'

server = Hapi.createServer '0.0.0.0', process.env.PORT || 8081, {}

server.route
    method: 'GET',
    path: '/{path*}',
    handler:
      directory:
        path: "./public"
        listing: false
        index: true

ts =
  filter: ''
  stream: null
  changeStream: (filter) =>
    ts.filter = filter

    # Inform all listeners that the filter changed.
    server.websocket.emit('newFilter', ts.filter)

    # Kill old streamer.
    if ts.stream?
      old = ts.stream
      old.removeAllListeners()
      old.stop (a,b,c) -> console.log 'stop', a,b,c

    # Create new stream with new filter.
    ts.stream = T.stream('statuses/filter', track: filter)
    ts.stream.on 'tweet', (tweet) ->
      server.websocket.emit 'tweet', tweet

# Start the server
server.start ->
  console.log "Hapi server started at " + server.info.uri
  server.websocket = SocketIO.listen server.listener, log: false

  server.websocket.on 'connection', (socket) ->
    # Emit to clients new clients count.
    server.websocket.emit 'clientsCount', server.websocket.engine.clientsCount

    # Send to new client what the current filter is if any.
    socket.emit 'newFilter', ts.filter

    # When the client disconnects, send to remaining clients the new clients count.
    socket.on 'disconnect', ->
      server.websocket.emit 'clientsCount', server.websocket.engine.clientsCount

    # Client sent a new filter.
    socket.on 'newFilter', (filter) ->
      # Create new twitter stream with the new filter.
      ts.changeStream(filter)
