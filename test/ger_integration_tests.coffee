chai = require 'chai'  
should = chai.should()
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)

sinon = require 'sinon'

MemoryESM = require('../lib/memory_esm')
PsqlESM = require('../lib/psql_esm')

GER_Package = require('../ger')
GER = GER_Package.GER
q = require 'q'

knex = GER_Package.knex({client: 'pg', connection: {host: '127.0.0.1', user : 'root', password : 'abcdEF123456', database : 'ger_test'}})


create_psql_esm = ->
  #in
  psql_esm = new PsqlESM(knex)
  #drop the current tables, reinit the tables, return the esm
  q.fcall(-> psql_esm.drop_tables())
  .then( -> psql_esm.init_tables())
  .then( -> psql_esm)

create_store_esm = ->
  q.fcall( -> new MemoryESM())

for esmfn in [ create_store_esm, create_psql_esm]
  do (esmfn) ->
    init_ger = ->
      esmfn().then( (esm) -> new GER(esm))

    describe '#probability_of_person_actioning_thing', ->
      it 'should return 1 if the person has already actioned the object', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','buy','c'),
            ger.event('p1','view','c'),
          ])
          .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
          .then((probability) ->
            probability.should.equal 1
          )
        

      it 'should return 0 if the person has never interacted with the thing', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','buy','c'),
            ger.event('p1','view','c'),
          ])
          .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'd'))
          .then((probability) ->
            probability.should.equal 0
          )

      it 'should return the weight of the action', ->
        init_ger()
        .then (ger) ->
          ger.set_action_weight('view', 5)
          .then(-> ger.event('p1','view','c'))
          .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
          .then((probability) ->
            probability.should.equal 5
          )

      it 'should return the sum of the weights of the action', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.set_action_weight('view', 5),
            ger.set_action_weight('like', 10),
          ])
          .then( -> 
            q.all([
              ger.event('p1','view','c'),
              ger.event('p1','like','c')
            ])
          )
          .then(-> ger.probability_of_person_actioning_thing('p1', 'buy', 'c'))
          .then((probability) ->
            probability.should.equal 15
          )

    describe 'recommendations_for_thing', ->
      it 'should take a thing and action and return people that it reccommends', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','view','c'),

            ger.event('p2','view','c'),
            ger.event('p2','buy','c'),

          ])
          .then(-> ger.recommendations_for_thing('c', 'buy'))
          .then((people_weights) ->
            people_weights[1].person.should.equal 'p1'
            people_weights.length.should.equal 2
          )

    describe 'recommendations_for_person', ->
      
      it 'should reccommend basic things', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','buy','a'),
            ger.event('p1','view','a'),

            ger.event('p2','view','a'),
          ])
          .then(-> ger.recommendations_for_person('p2', 'buy'))
          .then((item_weights) ->
            item_weights[0].thing.should.equal 'a'
            item_weights.length.should.equal 1
          )

      it 'should take a person and action to reccommend things', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','buy','a'),
            ger.event('p1','view','a'),

            ger.event('p2','view','a'),
            ger.event('p2','buy','c'),
            ger.event('p2','buy','d'),

            ger.event('p3','view','a'),
            ger.event('p3','buy','c')
          ])
          .then(-> ger.recommendations_for_person('p1', 'buy'))
          .then((item_weights) ->
            #p1 already bought a, making it very likely to buy again
            #2/3 people buy c, 1/3 people buys d.
            items = (i.thing for i in item_weights)
            items[0].should.equal 'a'
            items[1].should.equal 'c'
            items[2].should.equal 'd'
          )

      it 'should take a person and reccommend some things', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','view','a'),

            ger.event('p2','view','a'),
            ger.event('p2','view','c'),
            ger.event('p2','view','d'),

            ger.event('p3','view','a'),
            ger.event('p3','view','c')
          ])
          .then(-> ger.recommendations_for_person('p1', 'view'))
          .then((item_weights) ->
            item_weights[0].thing.should.equal 'a'
            item_weights[1].thing.should.equal 'c'
            item_weights[2].thing.should.equal 'd'
            
          )

    describe 'similar things', ->
      it 'should take a thing action and return similar things', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','action1','thing1'),
            ger.event('p1','action1','thing2'),
          ])
          .then(-> ger.similar_things_for_action('thing1', 'action1'))
          .then((things) -> ('thing2' in things).should.equal true)
         
    describe 'similar people', ->
      it 'should take a person action and return similar people', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.event('p1','action1','thing1'),
            ger.event('p2','action1','thing1'),
          ])
          .then(-> ger.similar_people_for_action('p1', 'action1'))
          .then((people) -> ('p2' in people).should.equal true)

    describe 'ordered_similar_things', ->
      it 'should take a person and return promise for an ordered list of similar things', ->
        init_ger()
        .then (ger) ->
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
      it 'asd should take a person and return promise for an ordered list of similar people', ->
        init_ger()
        .then (ger) ->
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
            people[0].weight.should.equal 2
            people[1].person.should.equal 'p2'
            people[1].weight.should.equal 1
            people.length.should.equal 2
          )


    describe 'setting action weights', ->

      it 'should work getting all weights', ->
        init_ger()
        .then (ger) ->
          ger.set_action_weight('buybuy', 10)
          .then( (val) -> ger.set_action_weight('viewview', 1))
          .then( ->
            q.all([
              ger.event('p1', 'buybuy', 'a'),
              ger.event('p1', 'buybuy', 'b'),
              ger.event('p1', 'buybuy', 'c'),
              ])
          )
          .then(-> ger.esm.get_ordered_action_set_with_weights())
          .then((actions) -> 
            actions[0].key.should.equal "buybuy"
            actions[0].weight.should.equal 10
            actions[1].key.should.equal "viewview"
            actions[1].weight.should.equal 1
          )

      it 'should work multiple at the time', ->
        init_ger()
        .then (ger) ->
          q.all([
            ger.set_action_weight('viewview', 1),
            ger.set_action_weight('buybuy', 10),
          ])
          .then(-> ger.event('p1', 'buybuy', 'a'))
          .then(-> ger.get_action_weight('buybuy'))
          .then((weight) -> weight.should.equal 10)

      it 'should override existing weight', ->
        init_ger()
        .then (ger) ->
          ger.event('p1', 'buy', 'a')
          .then(-> ger.set_action_weight('buy', 10))
          .then(-> ger.get_action_weight('buy'))
          .then((weight) -> weight.should.equal 10)

      it 'should add the action with a weight to a sorted set', ->
        init_ger()
        .then (ger) ->
          ger.set_action_weight('buy', 10)
          .then(-> ger.get_action_weight('buy'))
          .then((weight) -> weight.should.equal 10)

      it 'should default the action weight to 1', ->
        init_ger()
        .then (ger) ->
          ger.add_action('buy')
          .then(-> ger.get_action_weight('buy'))
          .then((weight) -> weight.should.equal 1)
          .then(-> ger.set_action_weight('buy', 10))
          .then(-> ger.get_action_weight('buy'))
          .then((weight) -> weight.should.equal 10)

      it 'add_action should not override set_action_weight s', ->
        init_ger()
        .then (ger) ->
          ger.set_action_weight('buy', 10)
          .then(-> ger.get_action_weight('buy'))
          .then((weight) -> weight.should.equal 10)
          .then(-> ger.add_action('buy'))
          .then(-> ger.get_action_weight('buy'))
          .then((weight) -> weight.should.equal 10)