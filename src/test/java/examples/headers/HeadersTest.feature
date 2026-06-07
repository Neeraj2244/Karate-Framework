@Headers @SanityTest @RegressionTest
Feature: Working with Headers

  Background:
    * url httpBingoUrl
    * def token = 'dummy-token-xyz789'
    * header Authorization = 'Bearer ' + token
    * header X-API-Key = 'dummy-api-key-123'
    * header User-Agent = 'Karate/1.5.0'

  Scenario: API call with custom headers
    Given path 'headers'
    When method get
    Then status 200
    And match response.headers['X-Api-Key'] contains 'dummy-api-key-123'
    And match response.headers['User-Agent'] contains 'Karate/1.5.0'
    And match response.headers['Authorization'] contains 'Bearer dummy-token-xyz789'
