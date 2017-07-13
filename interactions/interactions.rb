#!/usr/bin/ruby

# Copyright 2017 Bright Computing Holding BV.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "rubygems"
require "open3"
require "json"
require "pp"
require 'optparse'
require "singleton"
require 'xmlsimple'
require 'hashdiff'


def s o, id=o.hash
  JSON.pretty_generate Hash[ id => o ]
end


def ppp o, id=o.hash
  puts p = (s o, id)
  STDOUT.flush
  p
end

def getClone o
  Marshal::load(Marshal.dump(o))
end


class MessageBroker
  attr_accessor :watchedTopics
  def initialize
    @watchedTopics = Hash.new { |watchedTopics, key| watchedTopics[key] = Array.new }
    @messageId = 0
  end

  def produce topics, message
    topics.select{|topic| @watchedTopics.has_key? topic }.each{ |watchedTopic|
      @watchedTopics[watchedTopic].push(message)
      }
  end

  def consume topic, consumerList=["puts"]
    consumerList.map{ |consumer|
      @watchedTopics[topic]
      method(consumer).call @watchedTopics[topic].pop(@watchedTopics[topic].size)
      }
  end
end

class Globals
  include Singleton
  attr_accessor :jsonFile
  attr_accessor :messageBroker
  attr_accessor :mainThreadFinished
  attr_accessor :signals
  attr_accessor :current
  attr_accessor :configurations
  attr_accessor :specialAttributes
  def initialize
    @jsonFile      = 'interactions.json'
    @messageBroker = MessageBroker.new
    @mainThreadFinished = false
    @signals = Hash.new false
    @current = "current"
    @configurations = Hash.new
    @specialAttributes = ["command", "interactions"]
  end
end



def prepareInteractions enum
  r = enum.map { |element|
    e = [ element ].flatten 1
    e
  }
  r
end

def combineInteractions enum
  #  enum must be an enumeration
  #  [ A , [ B, C ] ]  returns [ [A, B], [ A, C] ]
  enum = enum.map {|element|
    begin
      (combineInteractions element)
    rescue NoMethodError => e1 # element not an enumeration:
      element
    end
  }.flatten 1
  enum = prepareInteractions enum
  firstEnum = enum.first || []
  remainingEnum = enum[1..-1] || []
  r = (firstEnum.product *remainingEnum)
  r
end



def getChilds interactionsObject, interaction
  globals  = Globals.instance
  messageBroker = Globals.instance.messageBroker
  interactionsObject.default = Hash.new
  interactionsObject[interaction].default = Array.new
  messageBroker.produce ["all", "getChilds"],
    (s interactionsObject, "interactionsObject")
  messageBroker.produce ["all", "getChilds"],
    (s interactionsObject[interaction], "interactionsObject[#{interaction}]")
  messageBroker.produce ["all", "getChilds"],
    (s interactionsObject[interaction]["interactions"], "interactionsObject[#{interaction}][interactions]")
  interactionNames = interactionsObject[interaction]["interactions"] || []
  interactionNames = (combineInteractions interactionNames).flatten
  interactionsObject[interaction]["interactions"] = interactionNames
end


def getQueue interactionsObject, interactions
  globals  = Globals.instance
  interactions.map { |interaction|
    [interaction] +  getQueue(interactionsObject, getChilds(interactionsObject, interaction))
    }.flatten
end


def getAttributes(interactionsObject, interaction, excludeThese=["command", "interactions"])
  
end


def getTree interactionsObject, interactions, printAttributes=0
  specialKeys = Globals.instance.specialAttributes
  messageBroker = Globals.instance.messageBroker
  interactions.map { |interaction|
    interactionsObject.default = Hash.new
    interactionAttributes = (interactionsObject[interaction].keys() - specialKeys)

    messageBroker.produce ["all", "getTree", "interactionAttributes", interaction],
      (s interactionAttributes, "interactionAttributes of #{interaction}")

    interactionAttributesFormatted = ("(" + interactionAttributes.join(",") + ")")*printAttributes
    [interaction + interactionAttributesFormatted] +  getTree(interactionsObject, getChilds(interactionsObject, interaction), printAttributes)
  }
end


def literalReplace interactionObject, text
  interactionObject.default = String.new
  text
end


def replaceReplace interactionObject, text
  interactionObject.default = String.new
  interactionObject[text]
end


def replaceQuotedReplace interactionObject, text
  interactionObject.default = String.new
  ["", interactionObject[text], ""].join('"')
end


def processToText interactionObject, piece
  messageBroker = Globals.instance.messageBroker
  piece.map{|k, v|

    messageBroker.produce ["all", "processToText", k, v],  "processToText #{k}Replace interactionObject[#{v}]=#{interactionObject[v]}"

    method(k + "Replace").call(interactionObject, v)
  }.join
end


def serializeCommand interactionObject
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "serializeCommand"],
    (s interactionObject, "currentObject :: serializeCommand")

  interactionObject.default = Array.new
  serializedCommand = interactionObject["command"].map{ |piece|
      processToText interactionObject, piece
    }.join

  messageBroker.produce ["all", "serializeCommand"],
    (s serializedCommand, "serializedCommand in serializeCommand")

  serializedCommand
end


def serializeCommandStructure interactionsObject, interaction, command
  serialized = command.map{ |piece|
      processToText interactionsObject[interaction], piece
  }.join
end

def serialize interactionsObject, interaction, key
  messageBroker = Globals.instance.messageBroker
  interactionsObject.default = Hash.new
  interactionsObject[interaction].default = Array.new
  serialized = serializeCommandStructure interactionsObject, interaction, interactionsObject[interaction][key]

  messageBroker.produce ["all", "serialize"],
    (s serialized, "result of serialization (#{interaction})")

  serialized
end


def run command
  configurations = Globals.instance.configurations
  messageBroker = Globals.instance.messageBroker

  messageBroker.produce ["all", "run"],  "run begin"
  messageBroker.produce ["all", "run", "command"],  (s command, "command")
  messageBroker.produce ["all", "liveXML"], "<run>"
  messageBroker.produce ["all", "liveXML"], "<command>"
  messageBroker.produce ["all", "liveXML"], command.encode({:xml => :text })
  messageBroker.produce ["all", "live", "command"], command
  messageBroker.produce ["all", "liveXML"], "</command>"

  stdin, stdoutanderr = [[], []]
  configurations.default = false
  stdin, stdoutanderr = Open3.popen2e(":;" + command) if !configurations["dryRun"]
  messageBroker.produce ["all", "liveXML"], "<output>"
  output = stdoutanderr.map { |l|
		outputLine = "# " + l.to_s
		messageBroker.produce ["all", "live", "output"], outputLine
		messageBroker.produce ["all", "liveXML"], outputLine.encode({:xml => :text })
		outputLine
  }.join
  messageBroker.produce ["all", "liveXML"], "</output>"
  messageBroker.produce ["all", "liveXML"], "</run>"

  messageBroker.produce ["all", "run"],  (s output, "output")
  messageBroker.produce ["all", "run"],  "run end"
  output
end


def inherit interactionsObject, inheriteeInteraction, inheritedInteraction, update=false
  globals  = Globals.instance
  # TODO: "child" and "parent"  does not make sense anymore in this context. change vars name
  childInteraction  = inheriteeInteraction
  parentInteraction = inheritedInteraction
  interactionObjectParent = interactionsObject[parentInteraction]
  interactionObject = interactionsObject[childInteraction]
  globals.messageBroker.produce ["all", "makeInheritParents"],  "makeInheritParents begin"
  previousState = getClone interactionObject
  parentInteractionClone = getClone interactionObjectParent
  globals.messageBroker.produce ["all", "makeInheritParents"],  (s interactionObjectParent, "interactionObjectParent")
  globals.messageBroker.produce ["all", "makeInheritParents"],  (s parentInteractionClone, "parentInteractionClone")
  globals.messageBroker.produce ["all", "makeInheritParents"],  (s interactionObject, "interactionsObject before")
  parentInteractionClone["command"]      = Array.new  # parent's commands shouldn't be inherited/rerun.
  parentInteractionClone["interactions"] = Array.new  # parent's childs   shouldn't be inherited/rerun.
  if update
    # values of inheritedInteraction prevails (inheriteeInteraction updated) in case of key clash:
    interactionsObject[childInteraction].merge! parentInteractionClone
  else
    # values of inheriteeInteraction prevails:
    # values of inheriteeInteraction prevails (inheriteeInteraction updated) in case of key clash:
    interactionsObject[childInteraction] = parentInteractionClone.merge interactionObject
  end
  globals.messageBroker.produce ["all", "makeInheritParents"],  (s interactionObject, "interactionsObject after")
  globals.messageBroker.produce ["all", "makeInheritParents"],  "makeInheritParents end"
  previousState
end


def currentObjectUpdate interactionsObject, interaction, keys = interactionsObject[interaction].keys
  # updates interactionsObject["current"] (as set in globals) with the contents of interactionsObject[interaction]
  globals  = Globals.instance
  messageBroker = Globals.instance.messageBroker

  messageBroker.produce ["all", "currentObjectUpdate", interaction],
    "currentObjectUpdate(...,#{interaction}) begin"

  currentObjectId = globals.current
  interactionsObject[interaction].default = Array.new
  interactionObjectClone = Hash[
    keys.map {|key|
      [  (key)  ,   (getClone interactionsObject[interaction][key])  ]
    }
  ]
  interactionsObject[currentObjectId].merge! interactionObjectClone

  messageBroker.produce ["all", "currentObjectUpdate", interaction],
    "currentObjectUpdate(...,#{interaction}) end"

  interactionsObject[currentObjectId]
end


def buildTreeVisit interactionsObject, interaction
  globals  = Globals.instance
  currentObjectId = globals.current
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "buildTreeVisit", interaction, "testing", "finishVisit"],
    "buildTreeVisit(...,#{interaction}) begin"
  messageBroker.produce ["all", "liveXML"], "<buildTreeVisit>"
  messageBroker.produce ["all", "liveXML"], "<interaction>"
  messageBroker.produce ["all", "liveXML"], interaction.encode({:xml => :text })
  messageBroker.produce ["all", "liveXML"], "</interaction>"

  messageBroker.produce ["all", "testing", interaction],
    (s interactionsObject[interaction]["tests"], "interactionsObject[#{interaction}][tests] buildTreeVisit before tests")

  #  tests aren't much more than interactions run at the end:
  interactionsObject[interaction].default = Array.new
  interactionsObject[interaction]["interactions"].concat interactionsObject[interaction]["tests"]

  result = Hash[ getChilds(interactionsObject, interaction).map { |childInteraction| [
    (

     # encode isn't encoding single quotes, I am adding it manually. More encoding may be needed: http://www.ascii.cl/htmlcodes.htm
     messageBroker.produce ["all", "liveXML"], "<childInteraction interaction=#{(childInteraction.gsub "'", "&#39;" ).encode({:xml => :attr})}>"

     messageBroker.produce ["all", "buildTreeVisit", interaction, "currentObject"],
      "childInteraction = #{childInteraction}"
     messageBroker.produce ["all", "currentObject"],
      (s interactionsObject[currentObjectId], "currentObject #{interaction}::#{childInteraction} buildTreeVisit before")

     currentObjectUpdate interactionsObject, childInteraction

     messageBroker.produce ["all", "currentObject"],
      (s interactionsObject[currentObjectId], "currentObject #{interaction}::#{childInteraction} buildTreeVisit after 1st update")

     treeVisitResults = buildTreeVisit interactionsObject, childInteraction

     messageBroker.produce ["all", "currentObject"],
      (s interactionsObject[currentObjectId], "currentObject #{interaction}::#{childInteraction} buildTreeVisit after visits")

     serializedCommand = (serialize interactionsObject, currentObjectId, "command")

     currentObjectUpdate interactionsObject, interaction, ["command"]

     messageBroker.produce ["all", "currentObject"],
      (s interactionsObject[currentObjectId], "currentObject #{interaction}::#{interaction} buildTreeVisit after 2nd update")
     messageBroker.produce ["all", "buildTreeVisit", interaction, "currentObject"],
      (s serializedCommand, "serializedCommand for #{childInteraction}")

     serializedCommand
     ),
     (
		   after_run = [ treeVisitResults, (run serializedCommand)  ]
			 messageBroker.produce ["all", "liveXML"], "</childInteraction>"
       after_run
     )
  ] } ]

  messageBroker.produce ["all", "liveXML"], "</buildTreeVisit>"
  messageBroker.produce ["all", "currentObject"],
    (s interactionsObject[currentObjectId], "currentObject #{interaction}:: buildTreeVisit finishing visit")
  messageBroker.produce ["all", "buildTreeVisit", interaction, "testing", "finishVisit"],
    "buildTreeVisit(...,#{interaction}) end"
  result
end


def parseJSONFileToObject file
  # file whose contents are a JSON object, or a string whose contents are a JSON object
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "parseJSONFileToObject", file],
    "parseJSONFileToObject #{file} begin"

  object = Hash.new
  begin
    object = JSON.parse file
  rescue JSON::ParserError => e1
    begin
      object = JSON.parse IO.read file
    rescue => e2
      messageBroker.produce ["all", "warn", "warning", "parseJSONFileToObject", file],
      "invalid JSON file or contents #{file}:".concat(e1.message).concat(s e1.backtrace, "backtrace")
      messageBroker.produce ["all", "warn", "warning", "parseJSONFileToObject", file],
      "invalid JSON file or contents #{file}:".concat(e2.message).concat(s e2.backtrace, "backtrace")
    end
  end

  messageBroker.produce ["all", "parseJSONFileToObject", file],
    "parseJSONFileToObject #{file} end"

  object

end


def applyMocks interactionsObject
  interactionsObjectClone = getClone interactionsObject # this is for debugging/getting its diff
  messageBroker = Globals.instance.messageBroker

  messageBroker.produce ["all", "applyMocks"],
    "applyMocks begin"

  Globals.instance.configurations.default = Array.new
  mocks = Globals.instance.configurations["mocks"]
  mocks.flatten!
  interactionsObject.default = Hash.new

  messageBroker.produce ["all", "applyMocksDeep", "interactionsObject"],
    (s interactionsObject, "interactionsObject before applying mocks")

  mocks.map { |mock|
    mockObject = parseJSONFileToObject mock
    interactionsObject.merge! mockObject

    messageBroker.produce ["all", "applyMocksDeep", mock],
      (s mockObject, "mockObject")
    messageBroker.produce ["all", "applyMocksDeep", mock],
      (s (HashDiff.diff interactionsObject, interactionsObjectClone), "interactionsObject diff after applying #{mock}")
  }

  messageBroker.produce ["all", "applyMocks", "applyMocksDeep"],
    (s (HashDiff.diff interactionsObject, interactionsObjectClone), "interactionsObject diff after applying mocks")
  messageBroker.produce ["all", "applyMocks", "interactionsObject"],
    (s interactionsObject, "interactionsObject after applying mocks")
  messageBroker.produce ["all", "applyMocks"],
    "applyMocks end"

  interactionsObject
end


def hashVisit nodeKey, nodeValue
  r = Array.new
  r.push nodeKey   if nodeKey != nil
  r.push nodeValue if nodeValue != nil
  r = (r.first if r.size == 1) || (r)

  begin
    r.to_h
  rescue TypeError
    r
  end
end


def getForkedObject interactionsObject, forkObject
  messageBroker = Globals.instance.messageBroker

  messageBroker.produce ["all", "getForkedObject"],
    "getForkedObject begin"

  messageBroker.produce ["all", "getForkedObject"],
      (s forkObject, "forkObject")

  forkedObject = (preEachVisitor (forkObject) {|nodeKey, nodeValue|
    r = hashVisit nodeKey,nodeValue

    messageBroker.produce ["all", "getForkedObjectDeep", "hashVisit"],
      (s r, "r")

    r
  }).to_h

  messageBroker.produce ["all", "getForkedObject"],
      (s forkedObject, "forkedObject")
  messageBroker.produce ["all", "getForkedObject"],
    "getForkedObject end"

  forkedObject
end


def matchInteractionNames interactionsObject, pattern
  # 
  # returns an array of interaction names matching pattern
  
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "matchInteractionNames"],
    "matchInteractionNames begin"

  messageBroker.produce ["all", "matchInteractionNames", pattern],
      (s pattern, "pattern")


  r = interactionsObject.map { |k, v|
   ( k.scan(Regexp.new(pattern)).size > 0? k : nil ) 
  }.flatten.select { |e| e }


  messageBroker.produce ["all", "matchInteractionNames", pattern],
      (s r, "interactions found")

  messageBroker.produce ["all", "matchInteractionNames"],
    "matchInteractionNames end"

  r

end


def matchInteractionValues interactionsObject, pattern
  # 
  # returns an array of the interactions (names) whose any of the values match the pattern
  
  methodName = __method__.to_s
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", methodName],
    "#{methodName} begin"

  messageBroker.produce ["all", methodName , pattern],
      (s pattern, "pattern")

  messageBroker.produce ["all", methodName, "#{methodName}Deep", "interactionsObject"],
      (s interactionsObject, "interactionsObject,")

  messageBroker.produce ["all", methodName, "interactionsObject.class" ],
      (s interactionsObject.class, "interactionsObject.class")

  r = Array.new


  interactionsObject ||= Hash.new
  r += interactionsObject.map { |k, v|
	  
    begin
			messageBroker.produce ["all", methodName, "#{methodName}Deep", "#{methodName}Kv"],
					(s k, "k");
			messageBroker.produce ["all", methodName, "#{methodName}Deep", "#{methodName}Kv"],
					(s v, "v");

			( v.scan(Regexp.new(pattern)).size > 0? k : nil )
    rescue NoMethodError # can't scan v, it is no string:
      # if  v is numeric there will be infinite recurssion! TODO
      # if  v is Array, it won't find matches
				( (matchInteractionValues v, pattern).size> 0? k: nil)
    end
  }.flatten.select { |e| e }


  messageBroker.produce ["all", methodName, pattern],
      (s r, "interactions found")

  messageBroker.produce ["all", methodName],
    "#{methodName} end"

  r

end


def selectPatterns interactionsObject
  methodName = __method__.to_s
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", methodName],
    "#{methodName} begin"

  Globals.instance.configurations.default = Array.new
  patterns = Globals.instance.configurations["patterns"]
  patterns.flatten!


  messageBroker.produce ["all", methodName],
      (s patterns, "patterns")


  namesMatched = patterns.map { |p|
   [
     (matchInteractionNames  interactionsObject, p),
   ]
  }.flatten


  valuesMatched = patterns.map { |p|
   [
     (matchInteractionValues interactionsObject, p)
   ]
  }.flatten

  matches = (namesMatched + valuesMatched).uniq


  messageBroker.produce ["all", methodName, "#{methodName}MatchedNames"],
      (s namesMatched, "selected interactions for matching names")

  messageBroker.produce ["all", methodName, "#{methodName}MatchedValues"],
      (s valuesMatched, "BUGGY TODO selected interactions for matching values")

  messageBroker.produce ["all", methodName, "#{methodName}Names"],
      (s matches, "selected interactions names")

  matchesObject = Hash.new
	matches.each { |match|
		matchesObject[match] = interactionsObject[match]
	}

  messageBroker.produce ["all", methodName, "#{methodName}MatchedObjects"],
      (s matchesObject, "selected interactions names")

  messageBroker.produce ["all", methodName],
    "#{methodName} end"

  matches
end


def matchHash object, pattern
  # 
  # returns a hash of string=>(array of hashes) having two keys: "keyMatches", "valueMatches"
  # object  is expected to be a hash.
  # 
  #  prepare object into tuples of k-v. in general, there is one k-v for each k,v of object, 
  #  unless v is an Array; then there is one k-v for each value of that array.
  #
  #  for every k,v of tuples:
  #  if k matches pattern, 
  #  - clone v
  #  - create a new hash having only one key. name that key as k and associate cloned_v to it
  #  - add such new hash to the array of "keyMatches"
  #
  #  if v matches pattern, 
  #  - clone v
  #  - create a new hash having only one key. name that key as k and associate cloned_v to it
  #  - add such new hash to the array of "valueMatches"
  #
  #  if, when trying to match v,  there was an exception, it was because v was
  #  - an array: try, then to 
  #  - a hash: 
  #
  #

  # returns a hash that contains all the key-object tuples in the object
  # separated in 4 keys: "keysAndValuesMatch", "onlyKeyMatch" and "onylValueMatch", 
  # "noMatch" depending on whether their keys and values match.
  # 
  # each one of those keys has an array of objects
  # 
  #  this is a recursive function. 
  # 
  
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "matchHash"],
    "matchHash begin"

  raise NotImplementedError
  messageBroker.produce ["all", "matchHash"],
    "matchHash end"

end


def applySubstitution interactionsObject, object, originalPattern , substitutePattern
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "applySubstitution"],
    "applySubstitution begin"

  raise NotImplementedError
  messageBroker.produce ["all", "applySubstitution"],
    "applySubstitution end"

end


def applyForks interactionsObject
  interactionsObjectClone = getClone interactionsObject # this is for debugging/getting its diff
  messageBroker = Globals.instance.messageBroker

  messageBroker.produce ["all", "applyForks"],
    "applyForks begin"

  Globals.instance.configurations.default = Array.new
  forks = Globals.instance.configurations["forks"]
  forks.flatten!

  messageBroker.produce ["all", "applyForks"],
    (s forks, "forks.flatten!")

  interactionsObject.default = Hash.new

  messageBroker.produce ["all", "applyForksDeep", "interactionsObject"],
    (s interactionsObject, "interactionsObject before applying forks")

  forks.map { |fork_|
    forkObject = parseJSONFileToObject fork_

    messageBroker.produce ["all", "applyForks", fork_],
      (s forkObject, "forkObject")

    forkedObject = (getForkedObject interactionsObject, forkObject)
    interactionsObject.merge! forkedObject

    messageBroker.produce ["all", "applyForks", fork_],
      (s forkedObject, "forkedObject")
    messageBroker.produce ["all", "applyForks", fork_],
      (s (HashDiff.diff interactionsObject, interactionsObjectClone), "interactionsObject diff after applying #{fork_}")
  }

  messageBroker.produce ["all", "applyForks", "applyForksDeep"],
    (s (HashDiff.diff interactionsObject, interactionsObjectClone), "interactionsObject diff after applying forks")
  messageBroker.produce ["all", "applyForks", "interactionsObject"],
    (s interactionsObject, "interactionsObject after applying forks")
  messageBroker.produce ["all", "applyForks"],
    "applyForks end"

  interactionsObject
end


def getInteractionDefinitions interactionsObject, interactions
  interactionsObject.default = Hash.new
  interactionsAfterMocks = Hash[ interactions.map { |interaction| [
    interaction,
    interactionsObject[interaction]
  ] } ]
  # interactions.map { |interaction|
  #   messageBroker.produce ["all", "mainThread", "interactionsAfterMocks", "interaction"],
  #     (s interactionsObject["interactions"][interaction] , "interaction=#{interaction} interactionsAfterMocks")
  # }
end


def mainThread options
  messageBroker = Globals.instance.messageBroker
  signals = Globals.instance.signals
  jsonFile = Globals.instance.jsonFile
  options.default = Array.new
  interactions = options["interactions"]
  configurations = Globals.instance.configurations

  # signal to the messageBroker  to start watching to the channels given as parameter
  options["topics"].each{ |topic| messageBroker.consume topic }

  messageBroker.produce ["all", "mainThread"],  "mainThread begin"

  # build the main object - interactionsObject, having information about all the interactions
  interactionsObject = Hash.new
  jsonFile = File.exists?(jsonFile) && jsonFile  || File.dirname(__FILE__) + '/' + jsonFile
  interactionsObject["interactions"] = parseJSONFileToObject jsonFile

  # select interactions.
  selectedInteractions = selectPatterns interactionsObject["interactions"]

	interactions += selectedInteractions if configurations["addSelection"] == true

  # apply the mock files. they're still passed as globals and not as parameter (they should be in options).
  applyMocks interactionsObject["interactions"]

  # outputs interactions as they were defined after mocks - only for message brokering/debug
  interactionsAfterMocks = getInteractionDefinitions interactionsObject["interactions"], interactions
  messageBroker.produce ["all", "mainThread", "interactionsAfterMocks"],
    (s interactionsAfterMocks, "interactionsAfterMocks")

  # apply the fork files. they're still passed as globals and not as parameter (they should be in options).
  applyForks interactionsObject["interactions"]

  # outputs interactions as they were defined after forks - only for message brokering/debug
  interactionsAfterMocks = getInteractionDefinitions interactionsObject["interactions"], interactions
  messageBroker.produce ["all", "mainThread", "interactionsAfterForks"],
    (s interactionsAfterMocks, "interactionsAfterMocks")

  # get tree - only for message brokering/debug
  messageBroker.produce ["all", "mainThread", "tree"],
    (JSON.pretty_generate Hash[ "tree" => (getTree interactionsObject["interactions"], interactions) ])

  messageBroker.produce ["all", "mainThread", "treeVisitor"],
    (s (preEachVisitor (getTree interactionsObject["interactions"], interactions) { |node| "visited #{node}"  }), "treeVisitor")

  # get treeWithAttributes - only for message brokering/debug
  messageBroker.produce ["all", "mainThread", "treeWithAttributes"],
    (JSON.pretty_generate Hash[ "treeWithAttributes" => (getTree interactionsObject["interactions"], interactions, 1) ])


  # get queue - only for message brokering/debug
  queue = getQueue interactionsObject["interactions"], interactions
  messageBroker.produce ["all", "mainThread", "queue"],
    (JSON.pretty_generate Hash[ "queue" => queue ])

  # actual run
  interactionsObject["interactions"]["root"] = Hash[ "interactions" => interactions ]
  results = buildTreeVisit interactionsObject["interactions"], "root"

  messageBroker.produce ["all", "mainThread", "results"],
    (JSON.pretty_generate Hash[ "results" => results ])

  # signal the end of this thread
  signals["mainThreadFinished"] = true
  messageBroker.produce ["all", "mainThread"],  "mainThread end"
end


def consumeTopicsThread topics
  messageBroker = Globals.instance.messageBroker
  signals = Globals.instance.signals
  messageBroker.produce ["all", "consumeTopicsThread"],  "consumeTopicsThread begin"

  while !signals["noMoreMessagesToConsume"] do
    signals["noMoreMessagesToConsume"] = signals["mainThreadFinished"]
    # if noMoreMessagesToConsume, still get the last message.
    topics.each{|topic| messageBroker.consume topic}
    STDOUT.flush
    sleep 1
  end

  messageBroker.produce ["all", "consumeTopicsThread"],  "consumeTopicsThread end"
  messageBroker.consume "consumeTopicsThread"
end


def main
  configurations = Globals.instance.configurations
  interactions = []
  topics  = ["live", "warning"]
  help = ""


  OptionParser.new do |opts|

    opts.on("-h", "--help", "displays help") do |u|
      help = "#{opts}"
    end

    opts.on("-m", "--mock-list mock1.json,mock2.json", Array, "list of json files containing mocks.") do |list|
      configurations["mocks"] ||= Array.new
      configurations["mocks"].push list
    end

    opts.on("-i", "--interactions INTERACTION1,INTERACTION2", Array, "interactions id, as in the json file.") do |list|
      interactions = list
    end

    opts.on("-f", "--fork fork.json", "JSON file containing fork instructions. The fork file can be inlined instead.") do |u|
      configurations["forks"] ||= Array.new
      configurations["forks"].push u
    end

    opts.on("-s", "--sellect pattern1,pattern2", Array, "Select interactions whose names match those patterns.") do |u|
      configurations["patterns"] ||= Array.new
      configurations["patterns"].push u
    end

    opts.on("--add-selection", "add selected interactions (with -s) to the interaction list") do |u|
      configurations["addSelection"] = true
    end

    opts.on("-d", "--debug CHANNEL1,CHANNEL2", Array, "debug channels. default is \"warning,live\".") do |list|
      topics = list
    end

    opts.on("--dry-run", "just generate commands for the interactions; don't really run then") do |u|
      configurations["dryRun"] = true
    end

  end.parse!


  threads = [ Thread.new { mainThread Hash["interactions" => interactions, "topics" => topics ] },
          Thread.new { consumeTopicsThread topics } ]
  threads.each {|t| t.join}

  puts help if !help.empty?
end


# functions from now on aren't yet used
def preEachVisitor treeObject, &doBlock
  messageBroker = Globals.instance.messageBroker
  messageBroker.produce ["all", "preEachVisitor", "preEachVisitorDeep"],  "preEachVisitor begin"

  doBlock ||= lambda {|arg|}
  r = (begin
    treeObject.map { |subTree|
      preEachVisitor subTree, &doBlock
    }
  rescue NoMethodError
    callResult = doBlock.call treeObject, &doBlock
  end )

  messageBroker.produce ["all", "preEachVisitorDeep", treeObject],  (s treeObject, "treeObject")
  messageBroker.produce ["all", "preEachVisitorDeep", treeObject],  (s r, "r")
  messageBroker.produce ["all", "preEachVisitor", "preEachVisitorDeep"],  "preEachVisitor end"
  r
end



main
