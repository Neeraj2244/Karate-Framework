@WebSocket @RegressionTest
Feature: WebSocket — Message Filtering and Accumulation

  # Handler filtering pattern:
  #   - onMessage fires for EVERY incoming frame
  #   - Only call queue.put() when the condition is true — effectively filtering messages
  #   - Use indexOf (JS built-in) instead of Java's contains() for string search in callbacks
  #   - Accumulate by polling N times for N expected messages
  # Karate 2.x inline array gotcha:
  #   - `def collected = [m1, m2, m3]` creates STRING LITERALS "m1","m2","m3" — NOT variable refs
  #   - Match each polled value individually: `match m1 == 'a'` etc.

  Background:
    * def WsClient  = Java.type('io.karatelabs.http.WsClient')
    * def TimeUnit  = Java.type('java.util.concurrent.TimeUnit')
    * configure afterScenario = function() { var s = karate.get('socket'); if (s != null) { karate.log('[TEARDOWN] Closing WebSocket'); s.close(); } }

  Scenario: Ignore noise messages and capture only the target message
    # Echo server echoes all three back; handler only queues the TARGET one
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * socket.onMessage(function(frame) { var t = frame.getText(); if (t.indexOf('TARGET') >= 0) queue.put(t) })
    * socket.send('NOISE_1')
    * socket.send('NOISE_2')
    * socket.send('TARGET_MESSAGE')
    * def result = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * match result == 'TARGET_MESSAGE'

  Scenario: Parse JSON frame and filter by type field
    # Simulates a server that streams multiple event types — only queue type=result
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * socket.onMessage(function(frame) { var d = karate.fromJson(frame.getText()); if (d.type == 'result') queue.put(frame.getText()) })
    * socket.send('{"type":"status","value":"processing"}')
    * socket.send('{"type":"heartbeat","ts":1000}')
    * socket.send('{"type":"result","value":42}')
    * def raw    = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * def result = karate.fromJson(raw)
    * match result.type  == 'result'
    * match result.value == 42

  Scenario: Collect multiple messages — poll three times for three echoes
    # All three echoes land in the queue; poll three times to collect each
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * socket.onMessage(function(frame) { queue.put(frame.getText()) })
    * socket.send('msg-alpha')
    * socket.send('msg-beta')
    * socket.send('msg-gamma')
    * def m1 = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * def m2 = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * def m3 = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * match m1 == 'msg-alpha'
    * match m2 == 'msg-beta'
    * match m3 == 'msg-gamma'
