
Feature: DummyJSON Login — token generation helper

  # Called exclusively via karate.callSingle() in karate-config.js.
  # Accepts: loginUrl, username, password as arguments.
  # Returns: accessToken, refreshToken (available to every feature via config).

  Scenario: POST /auth/login and capture tokens
    Given url loginUrl
    And header Content-Type = 'application/json'
    And request
      """
      {
        "username": "#(username)",
        "password": "#(password)",
        "expiresInMins": 30
      }
      """
    When method POST
    Then status 200
    And match response.accessToken  == '#string'
    And match response.refreshToken == '#string'
    And match response.username     == '#string'
    * def accessToken  = response.accessToken
    * def refreshToken = response.refreshToken
