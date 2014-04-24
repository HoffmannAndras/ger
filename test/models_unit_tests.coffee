chai = require 'chai'  
should = chai.should()
expect = chai.expect

sinon = require 'sinon'

ger_models = require('../lib/models')
KVStore = ger_models.KVStore
Set = ger_models.Set

describe 'store', ->
  it 'should be instanciatable', ->
    kv_store = new KVStore()

  it 'should set a value to a key, and return a promise', (done) ->
    kv_store = new KVStore()
    kv_store.set('key','value')
    .then(done , done)

  it 'a value should be retrievable from the store with a key', (done) ->
    kv_store = new KVStore()
    kv_store.set('key','value').then(=>
      kv_store.get('key')
    )
    .then((value) -> value.should.equal 'value'; return)
    .then(done , done)

describe 'set', ->
  it 'should be instanciatable', ->
    set = new Set

  it 'should add value and return a promise', (done) ->
    set = new Set()
    set.add('value')
    .then(done , done)

