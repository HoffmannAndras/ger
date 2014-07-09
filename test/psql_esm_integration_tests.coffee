chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

PsqlESM = require('../lib/psql_esm')

q = require 'q'

knex = require('knex')({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})

drop_tables = ->
  q.all([knex.schema.hasTable('events'), knex.schema.hasTable('actions')])
  .spread( (has_events_table, has_actions_table) ->
    p = []
    p.push knex.schema.dropTable('events') if has_events_table
    p.push knex.schema.dropTable('actions') if has_actions_table
    q.all(p)
  )

init_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  q.fcall(drop_tables)
  .then( -> psql_esm.init_database_tables())
  .then( -> psql_esm)

describe '#initial tables', ->
  it 'should have empty actions table', ->
    init_esm()
    .then (esm) ->
      knex.schema.hasTable('actions')
      .then( (has_table) ->
        has_table.should.equal true
        esm.count_actions()
      )
      .then( (count) ->
        count.should.equal 0
      )

  it 'should have empty events table', ->
    init_esm()
    .then (esm) ->
      knex.schema.hasTable('events')
      .then( (has_table) ->
        has_table.should.equal true
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 0
      )

describe '#add_event', ->
  it 'should add the action to the actions table', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        esm.count_actions()
      )
      .then( (count) ->
        count.should.equal 1
        esm.has_action('a')
      )
      .then( (has_action) ->
        has_action.should.equal true
      )

  it 'should add the event to the events table', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        esm.count_events()
      )
      .then( (count) ->
        count.should.equal 1
        esm.has_event('p','a', 't')
      )
      .then( (has_event) ->
        has_event.should.equal true
      )

describe 'add_action and set_action_weight', ->
  it 'should add action of weight 1, then set action should change it', ->
    init_esm()
    .then (esm) ->
      esm.add_action('a')
      .then( ->
        esm.get_action_weight('a')
      )
      .then( (weight) ->
        weight.should.equal 1
        esm.set_action_weight('a', 10).then( -> esm.get_action_weight('a'))
      )
      .then( (weight) ->
        weight.should.equal 10
      )

describe '#has_person_actioned_thing', ->
  it 'should return things people', ->
    init_esm()
    .then (esm) ->
      esm.add_event('p','a','t')
      .then( ->
        q.all([esm.has_person_actioned_thing('p', 'a', 't'), esm.has_person_actioned_thing('p', 'a', 'not_t')])
      )
      .spread( (t1, t2) ->
        t1.should.equal true
        t2.should.equal false
      )

describe '#get_actions_of_person_thing_with_weights', ->
  it 'should return action and weights', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p','a','t'),esm.add_event('p','a2','t')])
      .then( -> esm.set_action_weight('a',10))
      .then( -> esm.get_actions_of_person_thing_with_weights('p','t'))
      .then( (action_weights) ->
        action_weights[0].key.should.equal 'a'
        action_weights[0].weight.should.equal 10
        action_weights[1].key.should.equal 'a2'
        action_weights[1].weight.should.equal 1
      )

describe '#get_action_set', ->
  it 'should return actions', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p','a','t'),esm.add_event('p','a2','t')])
      .then( -> esm.get_action_set())
      .then( (actions) ->
        ('a' in actions).should.equal true
        ('a2' in actions).should.equal true
      )

describe '#get_action_set_with_weights', ->
  it 'should return actions with weights', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p','a','t'),esm.add_event('p','a2','t')])
      .then( -> esm.set_action_weight('a',10))
      .then( -> esm.get_action_set_with_weights())
      .then( (action_weights) ->
        action_weights[0].key.should.equal 'a'
        action_weights[0].weight.should.equal 10
        action_weights[1].key.should.equal 'a2'
        action_weights[1].weight.should.equal 1
      ) 


describe '#get_things_that_actioned_person', ->
  it 'should return list of things', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p','a','t'),esm.add_event('p','a','t1')])
      .then( -> esm.get_things_that_actioned_person('p','a'))
      .then( (things) ->
        ('t' in things).should.equal true
        ('t1' in things).should.equal true
      ) 

describe '#get_people_that_actioned_thing', ->
  it 'should return list of people', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p1','a','t'),esm.add_event('p2','a','t')])
      .then( -> esm.get_people_that_actioned_thing('t','a'))
      .then( (people) ->
        ('p1' in people).should.equal true
        ('p2' in people).should.equal true
      ) 


describe '#things_people_have_actioned', ->
  it 'should return list of things that people have actioned', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p1','a','t'),esm.add_event('p2','a','t1')])
      .then( -> esm.things_people_have_actioned('a',['p1','p2']))
      .then( (things) ->
        ('t' in things).should.equal true
        ('t1' in things).should.equal true
      ) 


describe '#people_jaccard_metric', ->
  it 'returns the jaccard distance of the two peoples action', ->
    init_esm()
    .then (esm) ->
      q.all([esm.add_event('p1','a','t'), esm.add_event('p2','a','t'), esm.add_event('p2','a','t1')])
      .then( -> esm.people_jaccard_metric('p1', 'p2', 'a'))
      .then( (jm) ->
        jm.should.equal 0.5
      ) 

