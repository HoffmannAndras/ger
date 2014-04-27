q = require 'q'

Store = require('./lib/store')

class GER
  constructor: () ->
    @store = new Store

  store: ->
    @store

  event: (person, action, thing) ->
    q.all([
      @add_action(action),
      @add_thing_to_person_action_set(person,action,thing)
      ])

  add_thing_to_person_action_set: (person , action, thing) ->

  similarity: (p1, p2) ->
    #return a value of a persons similarity

  similar_people: (person) ->
    #return a list of similar people, weighted breadth first search till some number is found

  update_reccommendations: (person) ->

  predict: (person) ->
    #return list of things

  actions: ->
    #return a list of actions

  add_action: (action, score=1) ->
    @store.add_to_sorted_set(action, score)
    #add action with weight

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


