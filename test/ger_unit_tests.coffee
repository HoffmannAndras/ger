chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

GER = require('../ger').GER

describe 'event', ->
  it 'should take a person action thing and return promise', (done) ->
    ger = new GER
    ger.event('person','action','thing')
    .then(done, done)

