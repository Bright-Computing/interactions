<!--
Copyright 2017 Bright Computing Holding BV.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-->

# interactionselastic.rb
It is a tool initiated with the intent of exporting the `interactions` from an
`interaction.json` file into an `Elasticsearch` cluster. Since `interaction.rb`
still doesn't have proper search powers, and `interaction.json` can grow big
very quickly, it may be handy to have an `Elasticsearch` cluster set for
searching in the contents of that file `interaction.json`.

But in the end, `interactionselastic.rb` is 1) a tool that can be used for exporting all
the objects in a `json` file to an `Elasticsearch` cluster, with:

```
ruby interactionselastic.rb populate_json_elastic_call  "http://localhost:9200" "index_of_mine" "interactions"  "http://url_to/interactions.json" | tee output.json
```
using the `populate_json_elastic_call` specification:
* it always take 5 parameters: `elasticsearch host:port`, `index name`, 
`document name`, `json path or url`



2) But also, `interactionselastic.rb` is a tool to interface with `Elasticsearch`,
so then you can do things like, creating a document ...

```
ruby interactionselastic.rb elastic_call  "http://localhost:9200" "index_of_mine" "interactions" "interaction_name" "" '{"key": "value" }'
```
... getting that document ...
```
ruby interactionselastic.rb  elastic_call  "http://localhost:9200" "index_of_mine" "interactions" "interaction_name" "" ''
```
... getting all `key:value` from a mapping ...
```
ruby  interactionselastic.rb  elastic_call  "http://localhost:9200" "index_of_mine" "interactions" "" "*:*" '' | tee output.json
```
... searching for a `key:value` (or any valid query, including changing `index_of_mine` by `_all`) ...
```
ruby  interactionselastic.rb  elastic_call  "http://localhost:9200" "index_of_mine" "interactions" "" "key:value" ''
```
and everything you can do with the simple specification of `elastic_call`:
* it always take 6 parameters: `elasticsearch host:port`, `index name`, `mapping name`,
`document name`, `search query`, `json document`
* make an argument explicitly empty if not interesting. so, `search query` empty means it is
no search,  `json document` is no `PUT` (`GET` therefore). the meaning for empty of other
is currently a WIP, so, don't trust the current behaviour, that they simply get empty.


Note: Scrolling not yet supported. It will always query for  `999999999` records, change source code if that's not OK 
(be aware that `Elasticsearch` may not accept a bigger one).


`STDOUT` Ouput is `JSON`, some garbage hard to parse may be output to the `STDERR`.


Requisites
----------
Ensure these gems are available:
```
require "json"
require "pp"
require "io/console"
require 'webrick'
require 'stringio'
require 'open-uri'
require 'curb'
require 'cgi'
```
