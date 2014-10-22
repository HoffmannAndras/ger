describe "weights", ->
  it "weights should represent the amount of actions needed to outweight them", ->
    init_ger()
    .then (ger) ->
      bb.all([
        ger.action('view', 1),
        ger.action('buy', 5),
        ger.event('p1','view','a'),
        ger.event('p1','buy','b'),

        ger.event('p6','buy','b'),
        ger.event('p6','buy','x'),

        ger.event('p2','view','a'),
        ger.event('p3','view','a'),
        ger.event('p4','view','a'),
        ger.event('p5','view','a')

        ger.event('p2','buy','y'),
        ger.event('p3','buy','y'),
        ger.event('p4','buy','y'),
        ger.event('p5','buy','y')
      ])
      .then(-> ger.recommendations_for_person('p1', 'buy'))
      .then((recs) ->
        #p1 is similar by 1 view to p2 p3 p4 p5
        #p1 is similar to p6 by 1 buy
        #because a buy is worth 5 views x should be recommended before y 
        recs[0].thing.should.equal 'b'
        recs[1].thing.should.equal 'y'
        recs[2].thing.should.equal 'x'
      )

describe "person exploits,", ->
  it "a single persons mass interaction should not outweigh 'real' interations", ->
    init_ger()
    .then (ger) ->
      rs = new Readable();
      for x in [1..100]
        rs.push("bad_person,view,t1,#{new Date().toISOString()},\n");
        rs.push("bad_person,buy,t1,#{new Date().toISOString()},\n");
      rs.push(null);
      ger.bootstrap(rs)
      .then( ->
        bb.all([
          ger.action('buy'),
          ger.action('view'),
          ger.event('real_person', 'view', 't2')
          ger.event('real_person', 'buy', 't2')
          ger.event('person', 'view', 't1')
          ger.event('person', 'view', 't2')
        ])
      )
      .then( ->
        ger.recommendations_for_person('person', 'buy')
      )
      .then( (recs) ->
        temp = {}
        (temp[tw.thing] = tw.weight for tw in recs)
        temp['t1'].should.equal temp['t2']
      )

