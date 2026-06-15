@WebSocket @RegressionTest
Feature: WebSocket — Multi-Step Interaction and Options

  # Covers:
  #   - Sequential send → poll chain (multi-step conversation)
  #   - One handler serves all steps — queue accumulates all frames
  #   - WsClientOptions builder: custom headers, maxPayloadSize
  #   - Binary WebSocket: WsFrame.binary() + frame.isBinary() + frame.getBytes()
  # Config:
  #   websocketUrl       (WEBSOCKET_URL env)        — pure echo, used by first two scenarios
  #   binaryWebsocketUrl (WEBSOCKET_BINARY_URL env) — binary-capable echo for the third scenario

  Background:
    * def WsClient        = Java.type('io.karatelabs.http.WsClient')
    * def WsClientOptions = Java.type('io.karatelabs.http.WsClientOptions')
    * def WsFrame         = Java.type('io.karatelabs.http.WsFrame')
    * def TimeUnit        = Java.type('java.util.concurrent.TimeUnit')
    * configure afterScenario = function() { var s = karate.get('socket'); if (s != null) { karate.log('[TEARDOWN] Closing WebSocket'); s.close(); } }

  Scenario: Multi-step conversation — each step builds on the previous response
    # Register one handler once; all echo responses land in queue in order
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(websocketUrl)
    * socket.onMessage(function(frame) { queue.put(frame.getText()) })

    # Step 1
    * socket.send('step-1')
    * def r1 = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * match r1 == 'step-1'

    # Step 2 — message is derived from step 1 result
    * def msg2 = r1 + '-done'
    * socket.send(msg2)
    * def r2 = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * match r2 == 'step-1-done'

    # Step 3 — JSON payload referencing step 2 result
    * socket.send('{"stage":"final","prev":"' + r2 + '"}')
    * def raw3  = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * def r3    = karate.fromJson(raw3)
    * match r3.stage == 'final'
    * match r3.prev  == 'step-1-done'


  Scenario: Connect with custom headers and maxPayloadSize via WsClientOptions builder
    # WsClientOptions.builder(url).header(key, value).maxPayloadSize(bytes).build()
    * def options = WsClientOptions.builder(websocketUrl).header('X-Test-Client', 'karate-ws').maxPayloadSize(1048576).build()
    * def queue   = new java.util.concurrent.LinkedBlockingQueue()
    * def socket  = WsClient.connect(options)
    * socket.onMessage(function(frame) { queue.put(frame.getText()) })
    * socket.send('ping-with-headers')
    * def result  = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * match result == 'ping-with-headers'

  Scenario: Binary WebSocket — send binary frame and receive binary echo
    # Uses binaryWebsocketUrl (echo.websocket.in) which echoes binary frames back.
    # ws.postman-echo.com/raw silently drops binary frames, so a dedicated URL is required.
    #
    # Two GraalJS callback gotchas avoided here:
    #   1. `new String(bytes)` — `String` resolves as the JS primitive, not java.lang.String
    #   2. `new (Java.type('java.lang.String'))(bytes)` — the result of Java.type() is not
    #      recognized as a constructor by GraalJS when called via `new`
    #   Fix: use java.nio.charset static methods (no constructor call needed):
    #     java.nio.charset.Charset.forName('UTF-8').decode(java.nio.ByteBuffer.wrap(bytes)).toString()
    #
    # echo.websocket.in sends a welcome banner on connect; filter it out in the handler.
    * def queue  = new java.util.concurrent.LinkedBlockingQueue()
    * def socket = WsClient.connect(binaryWebsocketUrl)
    * socket.onMessage(function(frame) { var c = frame.isBinary() ? java.nio.charset.Charset.forName('UTF-8').decode(java.nio.ByteBuffer.wrap(frame.getBytes())).toString() : frame.getText(); if (c != null && c.indexOf('Request served by') < 0) queue.put(c) })
    * def payload = 'binary-payload'
    * def bytes   = Java.type('java.lang.String').valueOf(payload).getBytes('UTF-8')
    * socket.send(WsFrame.binary(bytes))
    * def received = queue.poll(wsTimeoutSeconds, TimeUnit.SECONDS)
    * match received == 'binary-payload'
