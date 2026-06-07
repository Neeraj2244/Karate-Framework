@Retry @RegressionTest
Feature: Retry Until a condition is met

  Background:
    * url httpBingoUrl

  Scenario Outline: Wait for simulated processing to complete
    Given path 'delay', jobId
    And retry until responseStatus == 200
    When method get
    Then match response.url contains jobId

    Examples:
      | jobId |
      | 3     |
      | 5     |
      | 7     |
