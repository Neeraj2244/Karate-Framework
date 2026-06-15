@WebSocket @SanityTest
Feature: WebSocket — Basic Connection and Echo

  # Karate 2.x WebSocket pattern:
  #   - karate.webSocket() removed; use Java.type('io.karatelabs.http.WsClient')
  #   - 'listen' keyword removed; use LinkedBlockingQueue.poll(timeout, unit) to block
  #   - socket.onMessage(Consumer<WsFrame>) registers the message handler
  #   - frame.getText() reads the text payload; frame.isBinary() / frame.getBytes() for binary
  #   - queue.poll(n, TimeUnit) returns null on timeout — mirrors old 'listenResult == null'

  Background:
    * def WsClient  = Java.type('io.karatelabs.http.WsClient')
    * def TimeUnit  = Java.type('java.util.concurrent.TimeUnit')
    * configure afterScenario = function() { var s = karate.get('socket'); if (s != null) { karate.log('[TEARDOWN] Closing WebSocket'); s.close(); } }

  Scenario: Send plain text and receive echo
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * socket.onMessage(function(frame) { queue.put(frame.getText()) })
    * socket.send('hello karate')
    * def result = queue.poll(8, TimeUnit.SECONDS)
    * match result == 'hello karate'

  Scenario: Send JSON string and receive echo back as parsed object
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * socket.onMessage(function(frame) { queue.put(frame.getText()) })
    * def jsonStr = '{"action":"ping","id":1,"source":"karate-test"}'
    * socket.send(jsonStr)
    * def raw    = queue.poll(8, TimeUnit.SECONDS)
    * def result = karate.fromJson(raw)
    * match result.action == 'ping'
    * match result.id     == 1
    * match result.source == 'karate-test'

  Scenario: poll returns null on timeout when no message is sent
    # No send, no put — poll expires and returns null after 2 seconds
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * def result = queue.poll(2, TimeUnit.SECONDS)
    * match result == '#null'
