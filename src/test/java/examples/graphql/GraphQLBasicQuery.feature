@GraphQL @SanityTest
Feature: GraphQL — Inline Query and Mutation

  # Covers: text keyword, basic query, mutation, response.errors check
  # API: graphqlzero.almansi.me — JSONPlaceholder data exposed as GraphQL

  Background:
    * url graphqlUrl

  Scenario: Fetch user with inline text query
    Given text query =
      """
      {
        user(id: "1") {
          id
          name
          email
          username
        }
      }
      """
    And request { query: '#(query)' }
    When method POST
    Then status 200
    # GraphQL always returns 200 — must explicitly check for errors in body
    And match response.errors == '#notpresent'
    And match response.data.user.id       == '1'
    And match response.data.user.name     == 'Leanne Graham'
    And match response.data.user.email    == 'Sincere@april.biz'
    And match response.data.user.username == '#string'

  Scenario: Create post via mutation
    Given text mutation =
      """
      mutation {
        createPost(input: {
          title: "Karate GraphQL Test"
          body:  "Created via Karate inline mutation"
        }) {
          id
          title
          body
        }
      }
      """
    And request { query: '#(mutation)' }
    When method POST
    Then status 200
    And match response.errors                    == '#notpresent'
    And match response.data.createPost.id        == '#string'
    And match response.data.createPost.title     == 'Karate GraphQL Test'
    And match response.data.createPost.body      == 'Created via Karate inline mutation'

  Scenario: Update post via mutation
    Given text mutation =
      """
      mutation {
        updatePost(id: "1", input: {
          title: "Updated via Karate"
        }) {
          id
          title
        }
      }
      """
    And request { query: '#(mutation)' }
    When method POST
    Then status 200
    And match response.errors                == '#notpresent'
    And match response.data.updatePost.id    == '1'
    And match response.data.updatePost.title == 'Updated via Karate'

  Scenario: Delete post via mutation
    Given text mutation =
      """
      mutation {
        deletePost(id: "1")
      }
      """
    And request { query: '#(mutation)' }
    When method POST
    Then status 200
    And match response.errors           == '#notpresent'
    And match response.data.deletePost  == true
