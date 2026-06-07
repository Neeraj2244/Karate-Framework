@FileUpload 
Feature: File Upload

  Background:
    * url httpBingoUrl

  Scenario: Upload a document with additional fields
    Given path 'post'
    # Place a sample.pdf file in this same folder (src/test/java/examples/fileupload/) before running
    And multipart file myFile = { read: 'sample.pdf', filename: 'sample.pdf', contentType: 'application/pdf' }
    And multipart field description = 'Test document upload via Karate'
    When method post
    Then status 200
    And match response.files.myFile == '#notnull'
    And match response.form.description contains 'Test document upload via Karate'
