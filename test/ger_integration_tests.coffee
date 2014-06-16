chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

GER = require('../ger').GER
q = require 'q'

describe '#probability_of_person_actioning_thing', ->
  it 'should return 1 if the person has already actioned the object', ->
    ger = new GER
    q.all([
      ger.event('p1','buy','c'),
      ger.event('p1','view','c'),
    ])
    .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
    .then((probability) ->
      probability.should.equal 1
    )

  it 'should return 0 if the person has never interacted with the thing', ->
    ger = new GER
    q.all([
      ger.event('p1','buy','c'),
      ger.event('p1','view','c'),
    ])
    .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'd'))
    .then((probability) ->
      probability.should.equal 0
    )

  it 'should return the score of the action', ->
    ger = new GER
    q.all([
      ger.set_action_weight('view', 5),
      ger.event('p1','view','c'),
    ])
    .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
    .then((probability) ->
      probability.should.equal 5
    )

  it 'should return the sum of the scores of the action', ->
    ger = new GER
    q.all([
      ger.set_action_weight('view', 5),
      ger.set_action_weight('like', 10),
      ger.event('p1','view','c'),
      ger.event('p1','like','c'),
    ])
    .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
    .then((probability) ->
      probability.should.equal 15
    )

describe 'reccommendations_for_thing', ->
  it 'should take a thing and action and return people that it reccommends', ->
    ger = new GER
    q.all([
      ger.event('p1','view','c'),

      ger.event('p2','view','c'),
      ger.event('p2','buy','c'),

    ])
    .then(-> ger.reccommendations_for_thing('c', 'buy'))
    .then((people_scores) ->
      people_scores[1].person.should.equal 'p1'
      people_scores.length.should.equal 2
    )

describe 'reccommendations_for_person', ->
  
  it 'should reccommend basic things', ->
    ger = new GER
    q.all([
      ger.event('p1','buy','a'),
      ger.event('p1','view','a'),

      ger.event('p2','view','a'),
    ])
    .then(-> ger.reccommendations_for_person('p2', 'buy'))
    .then((item_scores) ->
      item_scores[0].thing.should.equal 'a'
      item_scores.length.should.equal 1
    )

  it 'should take a person and action to reccommend things', ->
    ger = new GER
    q.all([
      ger.event('p1','buy','a'),
      ger.event('p1','view','a'),

      ger.event('p2','view','a'),
      ger.event('p2','buy','c'),
      ger.event('p2','buy','d'),

      ger.event('p3','view','a'),
      ger.event('p3','buy','c')
    ])
    .then(-> ger.reccommendations_for_person('p1', 'buy'))
    .then((item_scores) ->
      #p1 already bought a, making it very likely to buy again
      #2/3 people buy c, 1/3 people buys d.
      items = (i.thing for i in item_scores)
      items[0].should.equal 'a'
      items[1].should.equal 'c'
      items[2].should.equal 'd'
    )

  it 'should take a person and reccommend some things', ->
    ger = new GER
    q.all([
      ger.event('p1','view','a'),

      ger.event('p2','view','a'),
      ger.event('p2','view','c'),
      ger.event('p2','view','d'),

      ger.event('p3','view','a'),
      ger.event('p3','view','c')
    ])
    .then(-> ger.reccommendations_for_person('p1', 'view'))
    .then((item_scores) ->
      item_scores[0].thing.should.equal 'a'
      item_scores[1].thing.should.equal 'c'
      item_scores[2].thing.should.equal 'd'
      
    )

describe 'things_people_have_actioned', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','a'),
      ger.event('p1','action1','b'),

      ger.event('p2','action1','a'),
      ger.event('p2','action1','c'),

      ger.event('p3','action1','a'),
      ger.event('p3','action1','d')
    ])
    .then(-> ger.things_people_have_actioned('action1', ['p2','p3']))
    .then((items) ->
      ('a' in items).should.equal true
      ('c' in items).should.equal true
      ('d' in items).should.equal true
      items.length.should.equal 3
    )

describe 'similar things', ->
  it 'should take a thing action and return similar things', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','thing1'),
      ger.event('p1','action1','thing2'),
    ])
    .then(-> ger.similar_things_for_action('thing1', 'action1'))
    .then((things) -> ('thing2' in things).should.equal true)
     
describe 'similar people', ->
  it 'should take a person action and return similar people', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','thing1'),
      ger.event('p2','action1','thing1'),
    ])
    .then(-> ger.similar_people_for_action('p1', 'action1'))
    .then((people) -> ('p2' in people).should.equal true)

describe 'ordered_similar_things', ->
  it 'should take a person and return promise for an ordered list of similar things', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','a'),
      ger.event('p1','action1','b'),
      ger.event('p1','action1','c'),

      ger.event('p2','action1','a'),
      ger.event('p2','action1','b'),

      ger.event('p3','action1','d')
    ])
    .then(-> ger.ordered_similar_things('a'))
    .then((things) ->
      things[0].thing.should.equal 'b'
      things[1].thing.should.equal 'c'
      things.length.should.equal 2
    )

describe 'ordered_similar_people', ->
  it 'should take a person and return promise for an ordered list of similar people', ->
    ger = new GER
    q.all([
      ger.event('p1','action1','a'),
      ger.event('p2','action1','a'),
      ger.event('p3','action1','a'),

      ger.event('p1','action1','b'),
      ger.event('p3','action1','b'),

      ger.event('p4','action1','d')
    ])
    .then(-> ger.ordered_similar_people('p1'))
    .then((people) ->
      people[0].person.should.equal 'p3'
      people[1].person.should.equal 'p2'
      people.length.should.equal 2
    )

describe 'similarity between things', ->
  it 'should take a things action person and return promise', ->
    ger = new GER
    q.all([
      ger.event('p1','viewed','a'),
      ger.event('p1', 'viewed', 'b'),
      ger.event('p1', 'viewed', 'c'),
      ger.event('p2','viewed','a'),
      ger.event('p2','viewed','b'),
      ger.event('p2','viewed','d')
    ])
    .then(-> ger.similarity_between_people('p1', 'p2'))
    .then((sim) -> sim.should.equal .5)

describe 'similarity between people', ->
  it 'should take a person action thing and return promise', ->
    ger = new GER
    q.all([
      ger.event('p1','viewed','a'),
      ger.event('p1', 'viewed', 'b'),
      ger.event('p1', 'viewed', 'c'),
      ger.event('p2','viewed','a'),
      ger.event('p2','viewed','b'),
      ger.event('p2','viewed','d')
    ])
    .then(-> ger.similarity_between_people('p1', 'p2'))
    .then((sim) -> sim.should.equal .5)

 it 'should take into consideration the weights of the actions', ->
    ger = new GER
    q.all([
      ger.set_action_weight('view', 1),
      ger.set_action_weight('buy', 10),

      ger.event('p1', 'buy', 'a'),
      ger.event('p1', 'buy', 'b'),
      ger.event('p1', 'buy', 'c'),
      ger.event('p1', 'buy', 'd'),
      ger.event('p2', 'buy', 'a'),

      ger.event('p1', 'view','a'),
      ger.event('p1', 'view','b'),
      ger.event('p2', 'view','a'),
    ])
    .then(-> ger.similarity_between_people('p1', 'p2'))
    .then((sim) -> sim.should.equal 3)

describe 'setting action weights', ->

  it 'should override existing weight', ->
    ger = new GER
    ger.event('p1', 'buy', 'a')
    .then(-> ger.set_action_weight('buy', 10))
    .then(-> ger.get_action_weight('buy'))
    .then((weight) -> weight.should.equal 10)

  it 'should add the action with a weight to a sorted set', ->
    ger = new GER
    ger.set_action_weight('buy', 10)
    .then(-> ger.get_action_weight('buy'))
    .then((weight) -> weight.should.equal 10)

  it 'should default the action weight to 1', ->
    ger = new GER
    ger.add_action('buy')
    .then(-> ger.get_action_weight('buy'))
    .then((weight) -> weight.should.equal 1)
    .then(-> ger.set_action_weight('buy', 10))
    .then(-> ger.get_action_weight('buy'))
    .then((weight) -> weight.should.equal 10)

  it 'add_action should not override set_action_weight s', ->
    ger = new GER
    ger.set_action_weight('buy', 10)
    .then(-> ger.get_action_weight('buy'))
    .then((weight) -> weight.should.equal 10)
    .then(-> ger.add_action('buy'))
    .then(-> ger.get_action_weight('buy'))
    .then((weight) -> weight.should.equal 10)