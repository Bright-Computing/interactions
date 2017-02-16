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

# elastic
It is a tool initiated with the intent of exporting the `interactions` from an
`interaction.json` file into an `Elasticsearch` cluster. Since `interaction.rb`
still doesn't have proper search powers, and `interaction.json` can grow big
very quickly, it may be handy to have an `Elasticsearch` cluster set for
searching in the contents of that file `interaction.json`.

But in the end, `elastic.rb` is 1) a tool that can be used for exporting all
the objects in a `json` file to an `Elasticsearch` cluster, with:

```
ruby elastic.rb populate_json_elastic_call  "http://localhost:9200" "populate_interactions"  "http://url_to/interactions.json"
```
using the `populate_json_elastic_call` specification (Currently the example above is what works,
but the below spec is the final one):
* it always take 5 parameters: `elasticsearch host:port`, `index name`, `mapping name`,
`document name`, `json path or url`


2) But also, `elastic.rb` is a tool to interface with `Elasticsearch`,
so then you can do things like, creating a document ...

```
ruby elastic.rb elastic_call  "http://localhost:9200" "blog" "post" "4" "" '{"user": "dilbert" }'
```
... getting that document ...
```
ruby elastic.rb  elastic_call  "http://localhost:9200" "blog" "post" "4" "" ''
```
... searching for a `key:value` (or any valid query) ...
```
ruby  elastic.rb  elastic_call  "http://localhost:9200" "blog" "post" "" "user:dilbert" ''
```
and everything you can do with the simple specification of `elastic_call`:
* it always take 6 parameters: `elasticsearch host:port`, `index name`, `mapping name`,
`document name`, `search query`, `json document`
* make an argument explicitly empty if not interesting. so, `search query` empty means it is
no search,  `json document` is no `PUT` (`GET` therefore). the meaning for empty of other
is currently a WIP, so, don't trust the current behaviour, that they simply get empty.



Ouput is `JSON`, but some garbage may be output to the `STDERR`.


