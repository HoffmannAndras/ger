chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

MemoryESM = require('../lib/memory_esm')

GER = require('../ger').GER
q = require 'q'

init_ger = ->
  return new GER(new MemoryESM())


describe '#recommendations_for_person', ->
  it 'should return a list of reccommended items', ->
    ger = init_ger()
    sinon.stub(ger,'ordered_similar_people', () -> q.fcall(-> [{person: 'p1', weight: 1}, {person: 'p2', weight: 3}]))
    sinon.stub(ger.esm,'things_people_have_actioned', -> q.fcall(-> ['t1','t2']))
    sinon.stub(ger, 'weighted_probabilities_to_action_things_by_people', (things, action, people_weights) -> 
      return {'t1':0.2 , 't2': 0.5}
    )
    ger.recommendations_for_person('p1','view')
    .then( (thing_weights) -> 
      thing_weights[0].thing.should.equal 't2'
      thing_weights[0].weight.should.equal .5
      thing_weights[1].thing.should.equal 't1'
      thing_weights[1].weight.should.equal .2
    )


describe '#ordered_similar_people', ->
  it 'should return a list of similar people ordered by similarity', ->
    ger = init_ger()
    sinon.stub(ger.esm, 'get_ordered_action_set_with_weights', -> q.fcall -> [{key: 'a', weight: 1}])
    sinon.stub(ger, 'similar_people_for_action_with_weights', -> q.fcall -> [{person: 'p3', weight: 1}, {person: 'p3', weight: 1}, {person: 'p2', weight: 1}] )
    ger.ordered_similar_people('p1')
    .then((people) -> 
      people[0].person.should.equal 'p3'
      people[1].person.should.equal 'p2'
    )



describe '#similar_people_for_action', ->
  it 'should take a person and find similar people for an action', ->
    ger = init_ger()
    sinon.stub(ger.esm, 'get_things_that_actioned_person', -> q.fcall(-> ['thing1']))
    sinon.stub(ger.esm, 'get_people_that_actioned_thing', -> q.fcall(-> ['person2']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )


  it 'should remove the passed person', ->
    ger = init_ger()
    sinon.stub(ger.esm, 'get_things_that_actioned_person', -> q.fcall(-> ['thing1']))
    sinon.stub(ger.esm, 'get_people_that_actioned_thing', -> q.fcall(-> ['person2', 'person1']))
    ger.similar_people_for_action('person1','action')
    .then((people) -> 
      ('person2' in people).should.equal true; 
      people.length.should.equal 1
    )


describe '#event', ->
  it 'should take a person action thing and return promise', ->
    ger = init_ger()
    ger.event('person','action','thing')

  it 'should add the action to the set of actions', ->
    ger = init_ger()
    sinon.stub(ger.esm, 'add_event', -> q.when())
    ger.event('person','action','thing')
    sinon.assert.calledOnce(ger.esm.add_event)


