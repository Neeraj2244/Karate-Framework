@GraphQL @RegressionTest
Feature: GraphQL — File-Based Queries and Dynamic Query Building

  # Covers:
  #   - read() with .graphql files (auto-treated as text, no text keyword needed)
  #   - replace keyword for conditional field inclusion at runtime

  Background:
    * url graphqlUrl

  Scenario: Fetch user with nested posts using .graphql file
    Given def query = read('get-user.graphql')
    And def variables = { id: '1' }
    And request { query: '#(query)', variables: '#(variables)' }
    When method POST
    Then status 200
    And match response.errors == '#notpresent'
    And match response.data.user.name  == 'Leanne Graham'
    And match response.data.user.email == 'Sincere@april.biz'
    And match response.data.user.posts.data == '#[] #notnull'
    And match each response.data.user.posts.data == { id: '#string', title: '#string' }

  Scenario: Create post using mutation from .graphql file
    Given def query = read('create-post.graphql')
    And def variables =
      """
      {
        "input": {
          "title": "Karate File-Based Mutation",
          "body":  "Loaded from create-post.graphql"
        }
      }
      """
    And request { query: '#(query)', variables: '#(variables)' }
    When method POST
    Then status 200
    And match response.errors                == '#notpresent'
    And match response.data.createPost.id    == '#string'
    And match response.data.createPost.title == 'Karate File-Based Mutation'

  Scenario: Dynamically include optional fields using replace keyword
    # replace swaps <tokens> in a template — one token per field avoids multi-word parse issues
    Given text queryTemplate =
      """
      {
        user(id: <userId>) {
          id
          name
          <field1>
          <field2>
          <field3>
        }
      }
      """
    And replace queryTemplate
      | token    | value     |
      | <userId> | 1         |
      | <field1> | 'email'   |
      | <field2> | 'phone'   |
      | <field3> | 'website' |
    And request { query: '#(queryTemplate)' }
    When method POST
    Then status 200
    And match response.errors            == '#notpresent'
    And match response.data.user.email   == '#string'
    And match response.data.user.phone   == '#string'
    And match response.data.user.website == '#string'
