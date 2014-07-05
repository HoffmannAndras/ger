chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

Store = require('../lib/store')

GER = require('../ger').GER
q = require 'q'

init_ger = ->
  new GER(new Store)

describe '#get_actions_of_person_thing_with_scores', ->
  it 'should return action scores of just keys in actions', ->
    ger = init_ger()
    sinon.stub(ger, 'get_action_set_with_scores', -> q.fcall(-> [{key: 'view', score: 1} , {key: 'buy', score: 2} ]))
    sinon.stub(ger.store, 'set_members', -> q.fcall(-> ['buy']))
    ger.get_actions_of_person_thing_with_scores('x','y')
    .then( (action_scores) ->
      action_scores.length.should.equal 1
      action_scores[0].key.should.equal 'buy'
      action_scores[0].score.should.equal 2
    )



describe '#get_action_set_with_scores', ->
  it 'should return the actions with the scores', ->
    ger = init_ger()
    sinon.stub(ger.store,'set_rev_members_with_score', -> return q.fcall(-> true))
    ger.get_action_set_with_scores().should.eventually.equal true

describe '#reccommendations_for_person', ->
  it 'should return a list of reccommended items', ->
    ger = init_ger()
    sinon.stub(ger,'ordered_similar_people', () -> q.fcall(-> [{person: 'p1', score: 1}, {person: 'p2', score: 3}]))
    sinon.stub(ger,'things_people_have_actioned', -> q.fcall(-> ['t1','t2']))
    sinon.stub(ger, 'weighted_probability_to_action_thing_by_people', (thing, action, people_scores) -> 
      if thing == 't1'
        return .2
      else if thing == 't2'
        return .5
      else
        throw 'bad thing'
    )
    ger.reccommendations_for_person('p1','view')
    .then( (thing_scores) -> 
      thing_scores[0].thing.should.equal 't2'
      thing_scores[0].score.should.equal .5
      thing_scores[1].thing.should.equal 't1'
      thing_scores[1].score.should.equal .2
    )

describe '#has_person_actioned_thing', ->
  it 'should check store to see if a person contains a thing', ->
    ger = init_ger()
    sinon.stub(ger.store,'set_contains', (key,thing)-> thing.should.equal 'a')
    ger.has_person_actioned_thing('p1','view','a')

describe '#weighted_probability_to_action_thing_by_people', ->
  it 'should return a weight an item with people', ->
    ger = init_ger()
    sinon.stub(ger,'has_person_actioned_thing', (person,action,thing) -> 
      action.should.equal 'view'
      thing.should.equal 'i1'
      if person == 'p1'
        return q.fcall( -> true)
      else if person == 'p2'
        return q.fcall( -> false)
      throw 'bad person'
    )
    people_scores = [{person: 'p1', score: 1}, {person: 'p2', score: 3}]
    ger.weighted_probability_to_action_thing_by_people('i1', 'view', people_scores).should.eventually.equal .25


describe '#things_people_have_actioned', ->
  it 'should return a list of items that have been actioned by people', ->
    ger = init_ger()
    sinon.stub(ger.store,'set_union', (keys)->
      q.fcall( -> ['a', 'b'])
    )
    ger.things_people_have_actioned('viewed', ['p2','p3'])
    .then((items) ->
      ('a' in items).should.equal true
      ('b' in items).should.equal true
      items.length.should.equal 2
    )

describe '#ordered_similar_people', ->
  it 'should return a list of similar people ordered by similarity', ->
    ger = init_ger()
    sinon.stub(ger, 'similar_people', -> q.fcall(-> ['p2', 'p3']))
    sinon.stub(ger, 'similarity_between_people', (person1, person2) ->
      person1.should.equal 'p1'
      if person2 == 'p2'
        return q.fcall(-> 0.3)
      else if person2 == 'p3'
        q.fcall(-> 0.4)
      else 
        throw 'bad person'
    )
    ger.ordered_similar_people('p1')
    .then((people) -> 
      people[0].person.should.equal 'p3'
      people[1].person.should.equal 'p2'
    )

describe '#similarity_between_people', ->
  it 'should find the similarity_between_people by looking at their jaccard distance', ->
    ger = init_ger()
    sinon.stub(ger, 'get_action_set_with_scores', -> q.fcall(-> [{key: 'view', score: 1} , {key: 'buy', score: 1} ]))
    sinon.stub(ger, 'similarity_between_people_for_action', (person1, person2, action_key, action_score) ->
      person1.should.equal 'p1'
      person2.should.equal 'p2'
      if action_key == 'view'
        return q.fcall(-> 0.3)
      else if action_key == 'buy'
        q.fcall(-> 0.4)
      else 
        throw 'bad action'
    )
    ger.similarity_between_people('p1','p2')
    .then((sim) -> 
      sim.should.equal .7
    )


describe "#similarity_between_people_for_action", ->
  it 'should find the similarity people by looking at their jaccard distance', ->
    ger = init_ger()
    sinon.stub(ger, 'people_jaccard_metric', -> q.fcall(-> ))
    ger.similarity_between_people_for_action('person1', 'person2', 'action', '1')
    sinon.assert.calledOnce(ger.people_jaccard_metric) 
  
  it 'should find the similarity people by looking at their jaccard distance multiplied by score', ->
    ger = init_ger()
    sinon.stub(ger, 'people_jaccard_metric', -> q.fcall(-> 4))
    ger.similarity_between_people_for_action('person1', 'person2', 'action', '2').should.eventually.equal 8

describe "#similar_people", ->
  it 'should compile a list of similar people for all actions', ->
    ger = init_ger()
    sinon.stub(ger, 'get_action_set', -> q.fcall(-> ['view']))
    sinon.stub(ger, 'similar_people_for_action', (person,action) ->
      person.should.equal 'person1'
      action.should.equal 'view' 
      q.fcall(-> ['person2'])
    )
    ger.similar_people('person1')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

describe '#similar_people_for_action', ->
  it 'should take a person and find similar people for an action', ->
    ger = init_ger()
    sinon.stub(ger, 'get_person_action_set', -> q.fcall(-> ['thing1']))
    sinon.stub(ger, 'get_thing_action_set', -> q.fcall(-> ['person2']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

  it 'should remove duplicate people', ->
    ger = init_ger()
    sinon.stub(ger, 'get_person_action_set', -> q.fcall(-> ['thing1']))
    sinon.stub(ger, 'get_thing_action_set', -> q.fcall(-> ['person2', 'person2']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

  it 'should remove the passed person', ->
    ger = init_ger()
    sinon.stub(ger, 'get_person_action_set', -> q.fcall(-> ['thing1']))
    sinon.stub(ger, 'get_thing_action_set', -> q.fcall(-> ['person2', 'person1']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )

describe "#get_action_set", ->
  it 'should return a promise for the action things set', ->
    ger = init_ger()
    sinon.stub(ger.store, 'set_members')
    ger.get_action_set('action','thing')
    sinon.assert.calledOnce(ger.store.set_members)

describe '#get_thing_action_set', ->
  it 'should return a promise for the action things set', ->
    ger = init_ger()
    sinon.stub(ger.store, 'set_members')
    ger.get_thing_action_set('thing','action')
    sinon.assert.calledOnce(ger.store.set_members)

describe '#get_person_action_set', ->
  it 'should return a promise for the persons action set', ->
    ger = init_ger()
    sinon.stub(ger.store, 'set_members')
    ger.get_person_action_set('person','action')
    sinon.assert.calledOnce(ger.store.set_members)


describe '#event', ->
  it 'should take a person action thing and return promise', ->
    ger = init_ger()
    ger.event('person','action','thing')

  it 'should add the action to the set of actions', ->
    ger = init_ger()
    sinon.stub(ger, 'add_action')
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_action)

  it 'should add to the list of things the person has done', ->
    ger = init_ger()
    sinon.stub(ger, 'add_thing_to_person_action_set', (thing, action, person) -> 
      person.should.equal 'person'
      action.should.equal 'action'
      thing.should.equal 'thing'
    )
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_thing_to_person_action_set)

  it 'should add person to a list of people who did action to thing', ->
    ger = init_ger()
    sinon.stub(ger, 'add_person_to_thing_action_set', (person, action, thing) -> 
      person.should.equal 'person'
      action.should.equal 'action'
      thing.should.equal 'thing'
    )
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.add_person_to_thing_action_set)

describe 'add_thing_to_person_action_set', ->
  it 'should add thing to person action set in store, incrememnting by the number of times it occured', ->
    ger = init_ger()
    sinon.stub(ger.store, 'set_add', (key, thing) -> 
      thing.should.equal 'thing'
    )
    ger.add_thing_to_person_action_set('thing', 'action', 'person')
    sinon.assert.calledOnce(ger.store.set_add)

describe 'add_person_to_thing_action_set', ->
  it 'should add a person action set in store, incrememnting by the number of times it occured', ->
    ger = init_ger()
    sinon.stub(ger.store, 'set_add', (key, thing) -> 
      thing.should.equal 'thing'
    )
    ger.add_thing_to_person_action_set('thing', 'action', 'person')
    sinon.assert.calledOnce(ger.store.set_add)

describe 'add_action', ->
  it 'should add the action with a weight to a sorted set', ->
    ger = init_ger()
    sinon.stub(ger.store, 'sorted_set_score', -> q.fcall(-> null))
    sinon.stub(ger.store, 'sorted_set_add', (key, action) -> 
      action.should.equal 'view'
    )
    ger.add_action('view')
    .then( -> sinon.assert.calledOnce(ger.store.sorted_set_add))

  it 'should not override the score if the action is already added', ->
    ger = init_ger()
    sinon.stub(ger.store, 'sorted_set_score', -> q.fcall(-> 3))
    sinon.stub(ger.store, 'sorted_set_add')
    ger.add_action('view')
    .then(-> sinon.assert.notCalled(ger.store.sorted_set_add))


describe 'set_action_weight', ->
  it 'will override an actions score', ->
    ger = init_ger()
    sinon.stub(ger.store, 'sorted_set_add', (key, action, score) -> 
      action.should.equal 'view'
      score.should.equal 5
    )
    ger.set_action_weight('view', 5)
    sinon.assert.calledOnce(ger.store.sorted_set_add)

describe 'jaccard metric', ->
  it 'should take two keys to sets and return a number', ->
    ger = init_ger()
    sinon.stub(ger.store, 'set_union', (s1,s2) -> ['1','2','3','4'])
    sinon.stub(ger.store, 'set_intersection', (s1,s2) -> ['2','3'])
    ger.people_jaccard_metric('p1','p2', 'a1').should.eventually.equal(.5)
