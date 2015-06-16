actions = ["buy", "like", "view"]
people = [1..1000]
things = [1..100]

random_created_at = ->
  moment().subtract(_.random(0, 120), 'minutes')

esm_tests = (ESM) ->
  describe 'performance tests', ->
    ns = 'default'

    naction = 50
    nevents = 2000
    nevents_diff = 25
    nbevents = 10000
    nfindpeople = 100
    ncalcpeople = 100
    ncompact = 3
    nrecommendations = 20
    nrecpeople = 100

    it "adding #{nevents} events takes so much time", ->
      self = @
      console.log ""
      console.log ""
      console.log "####################################################"
      console.log "################# Performance Tests ################"
      console.log "####################################################"
      console.log ""
      console.log ""
      @timeout(360000)
      init_ger(ESM, ns)
      .then((ger) ->
        st = new Date().getTime()
        promises = []
        for x in [1..nevents]
          promises.push ger.event(ns, sample(people), sample(actions) , sample(things), created_at: random_created_at(), expires_at: tomorrow)
        bb.all(promises)
        .then(->
          et = new Date().getTime()
          time = et-st
          pe = time/nevents
          console.log "#{pe}ms per event"
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nevents/nevents_diff]
            events = []
            for y in [1..nevents_diff]
              events.push {namespace: ns, person: sample(people), action: sample(actions), thing: sample(things),created_at: random_created_at(), expires_at: tomorrow}
            promises.push ger.events(events)
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nevents
            console.log "#{pe}ms adding events in #{nevents_diff} per set"
          )
        )
        .then( ->
          st = new Date().getTime()

          rs = new Readable();
          for x in [1..nbevents]
            rs.push("#{sample(people)},#{sample(actions)},#{sample(things)},#{random_created_at().format()},#{tomorrow.format()}\n")
          rs.push(null);

          ger.bootstrap(ns, rs)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nbevents
            console.log "#{pe}ms per bootstrapped event"
          )
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..ncompact]
            promises.push ger.compact_database(ns, actions: actions)

          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/ncompact
            console.log "#{pe}ms for compact"
          )
        )
        .then( ->
          st = new Date().getTime()

          promises = []
          for x in [1..nfindpeople]
            promises.push ger.esm.find_similar_people(ns, sample(people), actions)
          bb.all(promises)

          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nfindpeople
            console.log "#{pe}ms per find_similar_people"
          )
        )
        .then( ->
          st = new Date().getTime()

          promises = []
          for x in [1..ncalcpeople]
            peeps = _.unique((sample(people) for i in [0..25]))
            promises.push ger.esm.calculate_similarities_from_person(ns, sample(people), peeps , actions)
          bb.all(promises)

          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/ncalcpeople
            console.log "#{pe}ms per calculate_similarities_from_person"
          )
        )
        .then( ->
          st = new Date().getTime()

          promises = []
          for x in [1..nrecpeople]
            peeps = _.unique((sample(people) for i in [0..25]))
            promises.push ger.esm.recently_actioned_things_by_people(ns, actions, peeps)
          bb.all(promises)

          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/ncalcpeople
            console.log "#{pe}ms per recently_actioned_things_by_people"
          )
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nrecommendations]
            promises.push ger.recommendations_for_person(ns, sample(people), actions: {buy:5, like:3, view:1})
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nrecommendations
            console.log "#{pe}ms per recommendations_for_person"
          )
        )
        .then( ->
          st = new Date().getTime()
          promises = []
          for x in [1..nrecommendations]
            promises.push ger.recommendations_for_thing(ns, sample(things), actions: {buy:5, like:3, view:1})
          bb.all(promises)
          .then(->
            et = new Date().getTime()
            time = et-st
            pe = time/nrecommendations
            console.log "#{pe}ms per recommendations_for_thing"
          )
        )
      )
      .then( ->
        console.log ""
        console.log ""
        console.log "####################################################"
        console.log "################# END OF Performance Tests #########"
        console.log "####################################################"
        console.log ""
        console.log ""
      )

for esm_name in esms
  name = esm_name.name
  esm = esm_name.esm
  describe "TESTING #{name}", ->
    esm_tests(esm)

