bb = require 'bluebird'
_ = require 'underscore'

class GER

  constructor: (@esm) ->
    @INITIAL_PERSON_WEIGHT = 10

    plural =
      'person' : 'people'
      'thing' : 'things'

    #defining mirror methods (methods that need to be reversable)
    for v in [{object: 'person', subject: 'thing'}, {object: 'thing', subject: 'person'}]
      do (v) =>
        ####################### GET SIMILAR OBJECTS TO OBJECT #################################
        @["similar_#{plural[v.object]}_for_action"] = (object, action) =>
          #return a list of similar objects, later will be breadth first search till some number is found
          @esm["get_#{plural[v.subject]}_that_actioned_#{v.object}"](object, action)
          .then( (subjects) => @esm["get_#{plural[v.object]}_that_actioned_#{plural[v.subject]}"](subjects, action))
          .then( (objects) => _.unique(objects))

        @["similar_#{plural[v.object]}_for_action_with_weights"] = (object, action, weight) =>
          @["similar_#{plural[v.object]}_for_action"](object, action)
          .then( (objects) =>
            #TODO try move this to SQL, @esm["get_jaccard_distances_between_#{plural[v.object]}_for_action"](object, objects, action)
            @esm["get_jaccard_distances_between_#{plural[v.object]}_for_action"](object, objects, action, weight)
          )


        @["weighted_similar_#{plural[v.object]}"] = (object) ->
          #TODO expencive call, could be cached for a few days as ordered set
          total_action_weight = 0
          @esm.get_ordered_action_set_with_weights()
          .then( (action_weights) =>
            # Recursively build a list of similar objects
            fn = (i) => 
              if i >= action_weights.length
                return bb.try(-> null)
              else
                @["similar_#{plural[v.object]}_for_action_with_weights"](object, action_weights[i].key, action_weights[i].weight)

            @get_list_to_size(fn, 0, [], @esm.similar_objects_limit)  
          ) 
          .then( (object_weights) =>
            #join the weights together
            temp = {}
            for ows in object_weights
              for p, w of ows
                  continue if p == undefined || w == NaN
                  temp[p] = 0 if p not of temp
                  temp[p] += w

            #normalise the list of and sort and truncate object weights
            pw = ([k, w] for k, w of temp).sort((a, b) -> b[1] - a[1])[...@esm.similar_objects_limit]
            
            ret = {map: temp, people : [] , total_weight: 0, ordered_list : pw}
            for person_weight in pw
              person = person_weight[0]
              weight = person_weight[1]
              ret.people.push person
              ret.total_weight += weight
            ret

          )

  get_list_to_size: (fn, i, list, size) =>
    #recursive promise that will resolve till either the end
    if list.length > size
      return bb.try(-> list)
    fn(i)
    .then( (new_list) =>
      return bb.try(-> list) if new_list == null 
      new_list = list.concat new_list
      i = i + 1
      @get_list_to_size(fn, i, new_list, size)
    )

  probability_of_person_actioning_thing: (object, action, subject) =>
      #probability of actions s
      #if it has already actioned it then it is 100%
      @esm.has_person_actioned_thing(object, action, subject)
      .then((inc) => 
        if inc 
          return 1
        else
          #TODO should return action_weight/total_action_weights e.g. view = 1 and buy = 10, return should equal 1/11
          @esm.get_actions_of_person_thing_with_weights(object, subject)
          .then( (action_weights) -> (as.weight for as in action_weights))
          .then( (action_weights) -> action_weights.reduce( ((x,y) -> x+y ), 0 ))
      )


  recommendations_for_thing: (thing, action) ->
    @esm.get_people_that_actioned_thing(thing, action)
    .then( (people) =>
      list_of_promises = bb.all( (@weighted_similar_people(p) for p in people) )
      bb.all( [people, list_of_promises] )
    )
    .spread( (people, peoples_lists) =>
      temp = {}
      for pl in peoples_lists
        for person, weight of pl.map
          temp[person] = 0 if person not of temp
          temp[person] += weight
      temp 
    )
    .then( (recommendations) ->
      weighted_people = ([person, weight] for person, weight of recommendations)
      sorted_people = weighted_people.sort((x, y) -> y[1] - x[1])
      for ts in sorted_people
        temp = {weight: ts[1], person: ts[0]}
    )

  recommendations_for_person: (person, action) ->
    #recommendations for object action from similar people
    #recommendations for object action from object, only looking at what they have already done
    #then join the two objects and sort
    @weighted_similar_people(person)
    .then( (people_weights) =>
      #A list of subjects that have been actioned by the similar objects, that have not been actioned by single object
      bb.all([people_weights, @esm.things_people_have_actioned(action, people_weights.people)])
    )
    .spread( ( people_weights, people_things) =>
      people_things
      # Weight the list of subjects by looking for the probability they are actioned by the similar objects
      things_weight = {}
      for person, things of people_things
        for thing in things
          things_weight[thing] = 0 if things_weight[thing] == undefined
          things_weight[thing] += people_weights.map[person]
      things_weight
    )
    .then( (recommendations) ->
      # {thing: weight} needs to be [{thing: thing, weight: weight}] sorted
      weight_things = ([thing, weight] for thing, weight of recommendations)
      sorted_things = weight_things.sort((x, y) -> y[1] - x[1])
      ret = []
      for ts in sorted_things
        temp = {weight: ts[1], thing: ts[0]}
        ret.push(temp)
      ret
    ) 

  ##Wrappers of the ESM

  count_events: ->
    @esm.count_events()

  event: (person, action, thing, dates = {}) ->
    @esm.add_event(person,action, thing, dates)
    .then( -> {person: person, action: action, thing: thing})

  action: (action, weight=1, override = true) ->
    @esm.set_action_weight(action, weight, override)
    .then( -> {action: action, weight: weight}) 

  find_event: (person, action, thing) ->
    @esm.find_event(person, action, thing)

  get_action:(action) ->
    @esm.get_action_weight(action)
    .then( (weight) -> 
      return null if weight == null
      {action: action, weight: weight}
    )

  bootstrap: (stream) ->
    #filename should be person, action, thing, created_at, expires_at
    #this will require manually adding the actions
    @esm.bootstrap(stream)
    

  #  DATABASE CLEANING #

  compact_database: ->
    # Do some smart (lossless) things to shrink the size of the database
    bb.all( [ @esm.remove_expired_events(), @esm.remove_non_unique_events()] )


  compact_database_to_size: (number_of_events) ->
    # Smartly Cut (lossy) the tail of the database (based on created_at) to a defined size
    #STEP 1
    bb.all([@esm.remove_superseded_events() , @esm.remove_excessive_user_events()])
    .then( => @count_events())
    .then( (count) => 
      if count <= number_of_events
        return count
      else
        @esm.remove_events_till_size(number_of_events)
    )



RET = {}

RET.GER = GER

knex = require 'knex'
RET.knex = knex

RET.PsqlESM = require('./lib/psql_esm')

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


