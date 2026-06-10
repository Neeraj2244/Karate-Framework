@Auth @SanityTest @RegressionTest
Feature: DummyJSON — Authenticated API Requests

  # dummyJsonToken is injected by karate-config.js via karate.callSingle().
  # It is generated ONCE per suite run — all 5 parallel threads share the same token.

  Background:
    * url dummyJsonUrl
    * header Authorization = 'Bearer ' + dummyJsonToken

  Scenario: GET /auth/me — verify access token is valid
    Given path 'auth', 'me'
    When method GET
    Then status 200
    And match response.username   == 'emilys'
    And match response.email      == '#string'
    And match response.id         == '#number'
    And match response.firstName  == '#string'
    And match response.lastName   == '#string'

  Scenario: GET /auth/me — validate full profile shape including nested objects
    Given path 'auth', 'me'
    When method GET
    Then status 200
    # match contains — partial match at top level, ignores extra fields
    And match response contains
      """
      {
        id:        '#number',
        username:  '#string',
        email:     '#string',
        firstName: '#string',
        lastName:  '#string',
        gender:    '#string',
        image:     '#string',
        age:       '#number',
        phone:     '#string'
      }
      """
    # nested objects need their own contains assertion — top-level contains does not recurse
    And match response.hair    contains { color: '#string', type: '#string' }
    And match response.address contains { city: '#string', country: '#string' }
