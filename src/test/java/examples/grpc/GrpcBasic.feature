@gRPC @SanityTest
Feature: gRPC — Basic Unary Calls via grpcurl

  # gRPC testing pattern for Karate standalone JAR (no Maven/Gradle required):
  #   - Uses grpcurl CLI to send gRPC requests and receive JSON responses
  #   - grpcbin Docker service exposes test endpoints at GRPC_HOST:GRPC_PORT (default localhost:9000)
  #   - Java ProcessBuilder executes grpcurl and captures stdout + stderr together
  #   - Karate asserts on the parsed JSON response exactly like REST tests
  #
  # Prerequisites (handled automatically in CI via grpc.yml workflow):
  #   - grpcurl installed and on PATH
  #   - grpcbin reachable at $GRPC_HOST:$GRPC_PORT
  #
  # Local run (Windows):
  #   1. docker run -d -p 9000:9000 moul/grpcbin
  #   2. winget install fullstorydev.grpcurl   (or scoop/choco)
  #   3. .\karate.ps1 tags "@gRPC"

  Background:
    * def ProcessBuilder = Java.type('java.lang.ProcessBuilder')
    * def Scanner        = Java.type('java.util.Scanner')

    * def grpcHost   = java.lang.System.getenv('GRPC_HOST') || 'localhost'
    * def grpcPort   = java.lang.System.getenv('GRPC_PORT') || '9000'
    * def grpcTarget = grpcHost + ':' + grpcPort

    # grpcCall — runs grpcurl and returns { exit, output } where output is raw JSON text
    * def grpcCall =
      """
      function(target, service, data) {
        var args = new java.util.ArrayList()
        args.add('grpcurl')
        args.add('-plaintext')
        args.add('-d')
        args.add(data)
        args.add(target)
        args.add(service)
        var pb = new ProcessBuilder(args)
        pb.redirectErrorStream(true)
        var proc   = pb.start()
        var sc     = new Scanner(proc.getInputStream(), 'UTF-8').useDelimiter('\\A')
        var output = sc.hasNext() ? sc.next() : ''
        var rc     = proc.waitFor()
        return { exit: rc, output: output.trim() }
      }
      """

    # grpcList — runs grpcurl without -d to list services or describe a method
    * def grpcList =
      """
      function(target, extra) {
        var args = new java.util.ArrayList()
        args.add('grpcurl')
        args.add('-plaintext')
        args.add(target)
        if (extra) args.add(extra)
        var pb = new ProcessBuilder(args)
        pb.redirectErrorStream(true)
        var proc   = pb.start()
        var sc     = new Scanner(proc.getInputStream(), 'UTF-8').useDelimiter('\\A')
        var output = sc.hasNext() ? sc.next() : ''
        var rc     = proc.waitFor()
        return { exit: rc, output: output.trim() }
      }
      """

  # ---------------------------------------------------------------------------
  Scenario: List gRPC services via server reflection
  # ---------------------------------------------------------------------------
    * def result = grpcList(grpcTarget, 'list')
    * match result.exit == 0
    * match result.output contains 'hello.HelloService'
    * match result.output contains 'addsvc.Add'

  # ---------------------------------------------------------------------------
  @SanityTest
  Scenario: SayHello — unary RPC returns personalised greeting
  # ---------------------------------------------------------------------------
    * def result = grpcCall(grpcTarget, 'hello.HelloService/SayHello', '{"greeting":"Karate"}')
    * match result.exit == 0
    * def response = karate.fromJson(result.output)
    * match response.reply == '#string'
    * match response.reply contains 'Karate'

  # ---------------------------------------------------------------------------
  @RegressionTest
  Scenario: Add/Sum — integer arithmetic over unary gRPC
  # ---------------------------------------------------------------------------
    * def result = grpcCall(grpcTarget, 'addsvc.Add/Sum', '{"a":"12","b":"8"}')
    * match result.exit == 0
    * def response = karate.fromJson(result.output)
    # int64 is JSON-encoded as a string in protobuf3
    * match response.v == '20'

  # ---------------------------------------------------------------------------
  @DataDriven @RegressionTest
  Scenario Outline: SayHello with different greetings (data-driven)
  # ---------------------------------------------------------------------------
    * def result = grpcCall(grpcTarget, 'hello.HelloService/SayHello', '{"greeting":"<name>"}')
    * match result.exit == 0
    * def response = karate.fromJson(result.output)
    * match response.reply contains '<name>'

    Examples:
      | name    |
      | Alice   |
      | Bob     |
      | Charlie |
