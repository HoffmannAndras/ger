describe '#event', ->
  it 'should upsert same events', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('buy'),
        ger.event('p1','buy','c'),
        ger.event('p1','buy','c'),
      ])
      .then(-> ger.count_events())
      .then((count) ->
        count.should.equal 1
      )

describe '#count_events', ->
  it 'should return 2 for 2 events', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.event('p1','buy','c'),
        ger.event('p1','view','c'),
      ])
      .then(-> ger.count_events())
      .then((count) ->
        count.should.equal 2
      )



describe 'recommendations_for_person', ->
  
  it 'asd should reccommend basic things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
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
      bb.all([
        ger.action('view'),
        ger.action('buy'),
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
        #p1 is similar to (p1 by 1), p2 by .5, and (p3 by .5)
        #p1 buys a (a is 1), p2 and p3 buys c (.5 + .5=1) and p2 buys d (.5)
        items = (i.thing for i in item_weights)
        (items[0] == 'a' or items[0] == 'c').should.equal true
        items[2].should.equal 'd'
      )

  it 'should take a person and reccommend some things', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view'),

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

  it 'should filter previously actioned things based on filter events option', ->
    init_ger(previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('buy'),
        ger.event('p1','buy','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((item_weights) ->
        item_weights.length.should.equal 0
      ) 

  it 'should filter previously actioned by someone else', ->
    init_ger(previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','buy','a'),
        ger.event('p2','buy','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((item_weights) ->
        item_weights.length.should.equal 0
      )

  it 'should not filter non actioned things', ->
    init_ger(previous_actions_filter: ['buy'])
    .then (ger) ->
      bb.all([
        ger.action('view'),
        ger.action('buy'),
        ger.event('p1','view','a'),
        ger.event('p2','view','a'),
        ger.event('p2','buy','a'),
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((item_weights) ->
        item_weights.length.should.equal 1
        item_weights[0].thing.should.equal 'a'
      ) 

  it 'should not break with weird names (SQL INJECTION)', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action("v'i\new"),
        ger.event("'p\n1","v'i\new","'a\n;"),
        ger.event("'p\n2","v'i\new","'a\n;"),
      ])
      .then(-> ger.recommendations_for_person("'p\n1","v'i\new"))
      .then((item_weights) ->
        item_weights[0].thing.should.equal "'a\n;"
        item_weights.length.should.equal 1
      )

describe 'weighted_similar_people', ->
  it 'should return a list of similar people weighted with jaccard distance', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.weighted_similar_people('p1', 'action1'))
      .then((people_weights) ->
        people_weights['p1'].should.equal 1
        people_weights['p3'].should.equal 1
        people_weights['p2'].should.equal 1/2
        Object.keys(people_weights).length.should.equal 3
      )

  it 'should handle a non associated event on person', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.event('p1','action1','not')
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),
        ger.event('p3','action1','a'),

        ger.event('p1','action1','b'),
        ger.event('p3','action1','b'),

        ger.event('p4','action1','d')
      ])
      .then(-> ger.weighted_similar_people('p1','action1'))
      .then((people_weights) ->
        compare_floats( people_weights['p3'], 2/3).should.equal true
        compare_floats( people_weights['p2'] ,1/3).should.equal true
        Object.keys(people_weights).length.should.equal 3
      )

  it 'should not use actions with 0 or negative weights', ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('action1'),
        ger.action('neg_action', 0),
        ger.event('p1','action1','a'),
        ger.event('p2','action1','a'),

        ger.event('p1','neg_action','a'),
        ger.event('p3','neg_action','a'),

      ])
      .then(-> ger.weighted_similar_people('p1','action1'))
      .then((people_weights) ->
        people_weights['p1'].should.exist
        people_weights['p2'].should.exist
        Object.keys(people_weights).length.should.equal 2
      )   

describe 'setting action weights', ->

  it 'should work getting all weights', ->
    init_ger()
    .then (ger) ->
      ger.action('buybuy', 10)
      .then( (val) -> ger.action('viewview', 1))
      .then( ->
        bb.all([
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
      bb.all([
        ger.action('viewview', 1),
        ger.action('buybuy', 10),
      ])
      .then(-> ger.event('p1', 'buybuy', 'a'))
      .then(-> ger.get_action('buybuy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should override existing weight', ->
    init_ger()
    .then (ger) ->
      ger.event('p1', 'buy', 'a')
      .then(-> ger.action('buy', 10))
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should add the action with a weight to a sorted set', ->
    init_ger()
    .then (ger) ->
      ger.action('buy', 10)
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)

  it 'should default the action weight to 1', ->
    init_ger()
    .then (ger) ->
      ger.action('buy')
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 1)
      .then(-> ger.action('buy', 10))
      .then(-> ger.get_action('buy'))
      .then((action) -> action.weight.should.equal 10)
