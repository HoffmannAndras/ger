q = require 'q'


class GER
  event: (person, action, thing) ->
    q.all([
      @add_action(action)
      ])

  similarity: (p1, p2) ->
    #return a value of a persons similarity

  similar_people: (person) ->
    #return a list of similar people, weighted breadth first search till some number is found

  update_reccommendations: (person) ->

  predict: (person) ->
    #return list of things

  actions: ->
    #return a list of actions

  add_action: (action) ->
    #add action with weight

RET = {}

RET.GER = GER

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return RET)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = RET;


