q = require 'q'

Store = require('./lib/store')

Utils =
  flatten: (arr) ->
    arr.reduce ((xs, el) ->
      if Array.isArray el
        xs.concat Utils.flatten el
      else
        xs.concat [el]), []

  unique : (arr)->
    output = {}
    output[arr[key]] = arr[key] for key in [0...arr.length]
    value for key, value of output

KeyManager =
  action_set_key : ->
    'action_set'

  person_action_set_key: (person, action)->
    "#{person}:#{action}"

  action_thing_set_key: (action,thing) ->
    "#{action}:#{thing}"

class GER
  constructor: () ->
    @store = new Store

  store: ->
    @store

  event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_thing_to_person_action_set(person,action,thing),
      @add_person_to_action_thing_set(person,action,thing)
      ])

  add_thing_to_person_action_set: (person , action, thing) ->
    @store.add_to_set(
      KeyManager.person_action_set_key(person, action),
      thing
    )

  add_person_to_action_thing_set: (person, action, thing) ->
    @store.add_to_set(
      KeyManager.action_thing_set_key(action, thing),
      person
    )

  get_person_action_set: (person, action) ->
    @store.set_members(KeyManager.person_action_set_key(person, action))

  get_action_thing_set: (action,thing) ->
    @store.set_members(KeyManager.action_thing_set_key(action, thing))

  similarity: (person1, person2) ->
    #return a value of a persons similarity

  similar_people_for_action: (person, action) ->
    #return a list of similar people, later will be breadth first search till some number is found
    @one_step_of_similar_people(person, action)

  one_step_of_similar_people: (person, action) ->
    @get_person_action_set(person, action)
    .then( (things) => q.all((@get_action_thing_set(action, thing) for thing in things)))
    .then( (people) => Utils.unique(Utils.flatten(people)))

  update_reccommendations: (person) ->

  predict: (person) ->
    #return list of things

  actions: ->
    #return a list of actions

  add_action: (action, score=1) ->
    @store.add_to_sorted_set(
      KeyManager.action_set_key(), 
      action, 
      score
    )
    #add action with weight

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


